import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/core/settings/app_preferences.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/location/controllers/compass_controller.dart';
import 'package:gps_camera/features/location/controllers/live_map_controller.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/location/controllers/place_controller.dart';
import 'package:gps_camera/features/location/utils/plus_code.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/models/watermark_template.dart';
import 'package:gps_camera/features/watermark/services/logo_service.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';
import 'package:gps_camera/features/watermark/widgets/watermark_preview.dart';

/// The watermark drawn live over the camera preview, exactly as the
/// automatic copy will look, with a live Google Map in the map square.
class LiveWatermarkOverlay extends StatefulWidget {
  const LiveWatermarkOverlay({
    super.key,
    required this.location,
    required this.place,
    required this.map,
    required this.settings,
  });

  final LocationController location;
  final PlaceController place;
  final LiveMapController map;
  final WatermarkSettingsStore settings;

  /// Virtual photo width the overlay is laid out for (portrait capture).
  static const double layoutWidth = 1080;

  @override
  State<LiveWatermarkOverlay> createState() => _LiveWatermarkOverlayState();
}

class _LiveWatermarkOverlayState extends State<LiveWatermarkOverlay> {
  late WatermarkConfig _config;
  late bool _enabled;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _reloadSettings();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _reloadSettings() {
    _config = widget.settings.load();
    _enabled = widget.settings.loadAutoWatermark();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) {
      return Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: ActionChip(
            avatar: const Icon(Icons.branding_watermark_outlined, size: 18),
            label: Text('Auto watermark off'.tr),
            onPressed: _openSheet,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / LiveWatermarkOverlay.layoutWidth;
        final virtual = Size(
          LiveWatermarkOverlay.layoutWidth,
          constraints.maxHeight / scale,
        );
        return Obx(() {
          final content = _liveContent();
          final mapImage = widget.map.image.value;
          final logo = Get.isRegistered<LogoService>()
              ? Get.find<LogoService>().image.value
              : null;
          final layout = WatermarkPainter(
            content: content,
            config: _config,
            imageSize: virtual,
            mapImage: mapImage,
            reserveMapSlot: true,
            logoImage: logo,
          );
          final mapRect = layout.mapRect;
          final bounds = layout.bounds;
          layout.dispose();

          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: WatermarkCanvasPainter(
                      content: content,
                      config: _config,
                      imageSize: virtual,
                      mapImage: mapImage,
                      reserveMapSlot: true,
                      logoImage: logo,
                    ),
                  ),
                ),
              ),
              if (mapRect != null && mapImage == null)
                Positioned(
                  left: mapRect.left * scale,
                  top: mapRect.top * scale,
                  width: mapRect.width * scale,
                  height: mapRect.height * scale,
                  child: _MapPlaceholder(
                    text: widget.map.available.value
                        ? 'Loading map…'.tr
                        : 'Map unavailable'.tr,
                  ),
                ),
              if (!bounds.isEmpty)
                Positioned(
                  left: bounds.left * scale,
                  top: bounds.top * scale,
                  width: bounds.width * scale,
                  height: bounds.height * scale,
                  child: Semantics(
                    button: true,
                    label: 'Watermark. Change template'.tr,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _openSheet,
                    ),
                  ),
                ),
            ],
          );
        });
      },
    );
  }

  /// The same metadata a photo taken now would get, so the preview matches
  /// the saved copy.
  WatermarkContent _liveContent() {
    final now = DateTime.now();
    final location = widget.location.snapshotAt(now);
    final fix = location.fix;
    final place = widget.place.place.value;
    final metadata =
        PhotoMetadata.create(
          imageFileName: 'live',
          capturedAt: now,
          location: location,
          note: Get.isRegistered<AppPreferences>()
              ? Get.find<AppPreferences>().captureNote.value
              : null,
          direction: Get.isRegistered<CompassController>()
              ? Get.find<CompassController>().direction.value
              : null,
        ).withPlace(
          place: fix == null || place == null
              ? null
              : place.at(
                  fix.latitude,
                  fix.longitude,
                  PlusCode.encode(fix.latitude, fix.longitude),
                ),
        );
    return WatermarkContent.from(metadata, _config);
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => _WatermarkSheet(settings: widget.settings),
    );
    if (mounted) setState(_reloadSettings);
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x33FFFFFF),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: context.text.labelSmall?.copyWith(
              color: AppColors.onViewfinder,
            ),
          ),
        ),
      ),
    );
  }
}

/// Template choice and the automatic-copy switch.
class _WatermarkSheet extends StatefulWidget {
  const _WatermarkSheet({required this.settings});

  final WatermarkSettingsStore settings;

  @override
  State<_WatermarkSheet> createState() => _WatermarkSheetState();
}

class _WatermarkSheetState extends State<_WatermarkSheet> {
  late WatermarkConfig _config = widget.settings.load();
  late bool _auto = widget.settings.loadAutoWatermark();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Watermark'.tr, style: context.text.titleLarge),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _auto,
              title: Text('Save a watermarked copy on capture'.tr),
              subtitle: Text('The original photo is always kept'.tr),
              onChanged: (value) async {
                setState(() => _auto = value);
                await widget.settings.saveAutoWatermark(value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final template in WatermarkTemplate.values)
                  ChoiceChip(
                    label: Text(template.label.tr),
                    selected: _config.template == template,
                    onSelected: (_) async {
                      setState(
                        () => _config = _config.copyWith(template: template),
                      );
                      await widget.settings.save(_config);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ('More options (details, size, position) are in the watermark '
                      'editor.')
                  .tr,
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
