import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/count_text.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/models/photo_spots.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/shared/widgets/empty_state_view.dart';
import 'package:gps_camera/shared/widgets/media_thumbnail.dart';

/// Every photo with a GPS location as a pin. Uses the gallery's current
/// filter and search, so the map shows what the list shows.
class PhotoMapView extends StatefulWidget {
  const PhotoMapView({super.key});

  @override
  State<PhotoMapView> createState() => _PhotoMapViewState();
}

class _PhotoMapViewState extends State<PhotoMapView> {
  final GalleryController _gallery = Get.find<GalleryController>();
  String? _key;
  bool _keyChecked = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    String? key;
    try {
      key = await const MethodChannel('com.locaproof.app/native')
          .invokeMethod<String>('mapKey');
    } catch (_) {
      key = null;
    }
    if (!mounted) return;
    setState(() {
      _key = key == null || key.isEmpty ? null : key;
      _keyChecked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final spots = PhotoSpots.from(_gallery.visible);
          final photos = spots.fold(0, (n, s) => n + s.photos.length);
          return Text(
            photos == 0
                ? 'Map'.tr
                : 'Map · @n photo'.trCount('Map · @n photos', photos, {
                    'n': '$photos',
                  }),
          );
        }),
      ),
      body: !_keyChecked
          ? const Center(child: CircularProgressIndicator())
          : _key == null
          ? EmptyStateView(
              icon: Icons.map_outlined,
              title: 'Map unavailable'.tr,
              message: 'No map key is set up in this build of the app.'.tr,
            )
          : Obx(() {
              final spots = PhotoSpots.from(_gallery.visible);
              if (spots.isEmpty) {
                return EmptyStateView(
                  icon: Icons.location_off_outlined,
                  title: 'No photos with a location'.tr,
                  message:
                      ('Photos taken with GPS appear here as pins. Check the '
                              'gallery filter and search.')
                          .tr,
                );
              }
              return _Map(
                apiKey: _key!,
                spots: spots,
                onOpen: (spot) => _openSpot(context, spot),
              );
            }),
    );
  }

  Future<void> _openSpot(BuildContext context, PhotoSpot spot) async {
    if (spot.photos.length == 1) {
      await _gallery.openPhoto(spot.photos.single);
      return;
    }
    final picked = await showModalBottomSheet<GalleryPhoto>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                spot.title ??
                    '@n photos here'.trParams({'n': '${spot.photos.length}'}),
                style: sheet.text.titleMedium,
              ),
            ),
            for (final photo in spot.photos)
              ListTile(
                leading: ClipRRect(
                  borderRadius: AppRadius.mdAll,
                  child: SizedBox.square(
                    dimension: 48,
                    child: MediaThumbnail(photo.path, cacheWidth: 144),
                  ),
                ),
                title: Text(
                  photo.metadata == null
                      ? photo.fileName
                      : PhotoInfoFormatter.captureShort(photo.metadata!),
                ),
                subtitle: photo.metadata?.note == null
                    ? null
                    : Text(
                        photo.metadata!.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: () => Navigator.of(sheet).pop(photo),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await _gallery.openPhoto(picked);
  }
}

class _Map extends StatelessWidget {
  const _Map({required this.apiKey, required this.spots, required this.onOpen});

  final String apiKey;
  final List<PhotoSpot> spots;
  final ValueChanged<PhotoSpot> onOpen;

  @override
  Widget build(BuildContext context) {
    final points = [for (final s in spots) s.point];
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: points.length == 1
            ? null
            : CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.all(64),
                maxZoom: 17,
              ),
        initialCenter: points.first,
        initialZoom: 16,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}{r}.png'
              '?apiKey={apiKey}',
          additionalOptions: {'apiKey': apiKey},
          retinaMode: RetinaMode.isHighDensity(context),
          maxNativeZoom: 20,
          userAgentPackageName: 'com.locaproof.app',
        ),
        MarkerLayer(
          markers: [
            for (final spot in spots)
              Marker(
                point: spot.point,
                width: 56,
                height: 56,
                child: _Pin(spot: spot, onTap: () => onOpen(spot)),
              ),
          ],
        ),
        const RichAttributionWidget(
          showFlutterMapAttribution: false,
          attributions: [
            TextSourceAttribution('Powered by Geoapify'),
            TextSourceAttribution('© OpenMapTiles'),
            TextSourceAttribution('© OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}

/// A round thumbnail of the newest photo at a spot, with a count badge.
class _Pin extends StatelessWidget {
  const _Pin({required this.spot, required this.onTap});

  final PhotoSpot spot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = spot.photos.length;
    return Semantics(
      button: true,
      label: spot.title == null
          ? '@n photo'.trCount('@n photos', count, {'n': '$count'})
          : '@n photo at @place'.trCount('@n photos at @place', count, {
              'n': '$count',
              'place': spot.title!,
            }),
      child: GestureDetector(
        onTap: onTap,
        child: Badge(
          isLabelVisible: count > 1,
          label: Text('$count'),
          backgroundColor: AppColors.accent,
          textColor: AppColors.onAccent,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(blurRadius: 6, color: Colors.black38),
              ],
            ),
            child: ClipOval(
              child: MediaThumbnail(
                spot.photos.first.path,
                cacheWidth: 156,
                showPlayMark: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
