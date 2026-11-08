import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/services/capture_enricher.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/location/controllers/place_controller.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/models/place_info.dart';
import 'package:gps_camera/features/location/services/place_service.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/reports/services/pdf_report_renderer.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/models/watermark_template.dart';
import 'package:gps_camera/features/watermark/services/image_processor.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';

import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

const _tongi = Placemark(
  street: 'WC62+8CJ, Road, Tongi, Dhaka Division, Bangladesh',
  locality: 'Tongi',
  administrativeArea: 'Dhaka Division',
  country: 'Bangladesh',
  isoCountryCode: 'BD',
  postalCode: '1710',
);

PlaceInfo _place({double lat = 23.910913, double lng = 90.401004}) => PlaceInfo(
  latitude: lat,
  longitude: lng,
  plusCode: '7MMGWC62+9C6',
  resolvedAt: DateTime.utc(2026, 11, 7, 5, 58),
  addressLine: 'WC62+8CJ, Road, Tongi, Dhaka Division, Bangladesh',
  locality: 'Tongi',
  administrativeArea: 'Dhaka Division',
  country: 'Bangladesh',
  countryCode: 'BD',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaceService', () {
    test('maps the geocoder result and always adds a Plus Code', () async {
      var calls = 0;
      final service = PlaceService(
        geocoder: (lat, lng) async {
          calls++;
          return [_tongi];
        },
        clock: () => DateTime.utc(2026, 11, 7, 6),
      );

      final place = await service.describe(23.910913, 90.401004);

      expect(calls, 1);
      expect(place.title, 'Tongi, Dhaka Division, Bangladesh');
      expect(place.addressLine, startsWith('WC62+8CJ, Road, Tongi'));
      expect(place.plusCode, startsWith('7MMGWC62+'));
      expect(place.flag, '🇧🇩');
      expect(place.latitude, 23.910913);
      expect(place.resolvedAt, DateTime.utc(2026, 11, 7, 6));
    });

    test('offline or failing lookups give no address, never a guess', () async {
      final failing = PlaceService(
        geocoder: (_, _) => throw Exception('offline'),
      );
      final slow = PlaceService(
        geocoder: (_, _) =>
            Future.delayed(const Duration(seconds: 5), () => [_tongi]),
        timeout: const Duration(milliseconds: 20),
      );
      final empty = PlaceService(geocoder: (_, _) async => const []);

      for (final service in [failing, slow, empty]) {
        final place = await service.describe(23.9, 90.4);
        expect(place.hasAddress, isFalse);
        expect(place.addressLine, isNull);
        expect(place.title, isNull);
        expect(place.plusCode, isNotEmpty);
      }
    });

    test('place JSON round-trips', () {
      final place = _place();
      final back = PlaceInfo.fromJson(
        jsonDecode(jsonEncode(place.toJson())) as Map<String, dynamic>,
      );
      expect(back.toJson(), place.toJson());
    });
  });

  group('metadata', () {
    test('version 1 sidecars still load without a place', () {
      final json = jsonDecode(phoneSidecarJson) as Map<String, dynamic>;
      final metadata = PhotoMetadata.fromJson(json);
      expect(metadata.place, isNull);
      expect(metadata.mapImageFileName, isNull);
    });

    test('adding a place never changes capture time or GPS values', () {
      final original = fixtureMetadata();
      final updated = original.withPlace(
        place: _place(),
        mapImageFileName: 'IMG_test_map.png',
      );
      final json = updated.toJson();

      expect(json['schemaVersion'], 2);
      expect(json['capturedAt'], original.toJson()['capturedAt']);
      expect(json['location'], original.toJson()['location']);
      expect(
        PhotoMetadata.fromJson(json).place!.title,
        'Tongi, Dhaka Division, Bangladesh',
      );
    });
  });

  group('PlaceController', () {
    late FakeLocationService location;
    late LocationController controller;
    late int lookups;
    late PlaceController places;
    var now = DateTime.utc(2026, 11, 7, 6);

    setUp(() async {
      now = DateTime.utc(2026, 11, 7, 6);
      lookups = 0;
      location = FakeLocationService();
      controller = LocationController(
        location,
        FakePermissionService(),
        clock: () => now,
      )..onInit();
      await controller.start();
      places = PlaceController(
        controller,
        PlaceService(
          geocoder: (_, _) async {
            lookups++;
            return [_tongi];
          },
          clock: () => now,
        ),
        clock: () => now,
      )..onInit();
    });

    tearDown(() {
      places.onClose();
      controller.onClose();
    });

    Future<void> fixAt(double lat, double lng) async {
      now = now.add(const Duration(seconds: 1));
      location.emit(testFix(latitude: lat, longitude: lng, timestamp: now));
      await pumpEventQueue();
    }

    test('looks up once, then only after moving or ageing', () async {
      await fixAt(23.910913, 90.401004);
      expect(lookups, 1);
      expect(places.place.value!.locality, 'Tongi');

      await fixAt(23.91095, 90.40102); // ~4 m
      expect(lookups, 1);

      await fixAt(23.9115, 90.4012); // ~70 m
      expect(lookups, 2);

      now = now.add(const Duration(minutes: 3));
      await fixAt(23.9115, 90.4012);
      expect(lookups, 3);
    });

    test(
      'a nearby capture reuses the address with its own Plus Code',
      () async {
        await fixAt(23.910913, 90.401004);
        final capture = testFix(latitude: 23.91093, longitude: 90.40102);

        final place = (await places.placeFor(capture))!;

        expect(lookups, 1);
        expect(place.latitude, 23.91093);
        expect(place.addressLine, _tongi.street);
        expect(await places.placeFor(null), isNull);
      },
    );

    test('a distant capture is looked up fresh', () async {
      await fixAt(23.910913, 90.401004);
      await places.placeFor(testFix(latitude: 23.95, longitude: 90.45));
      expect(lookups, 2);
    });
  });

  group('Map template', () {
    WatermarkContent content({LocationSnapshot? location, PlaceInfo? place}) =>
        WatermarkContent.from(
          fixtureMetadata(location: location).withPlace(place: place),
          const WatermarkConfig(template: WatermarkTemplate.map),
        );

    test('shows place, address and Plus Code from metadata', () {
      final c = content(place: _place());
      expect(c.placeTitle, 'Tongi, Dhaka Division, Bangladesh');
      expect(c.flag, '🇧🇩');
      expect(c.address, startsWith('WC62+8CJ'));
      expect(c.plusCode, '7MMGWC62+9C6');
      expect(c.canShowMap, isTrue);
    });

    test('reserves a map square only when there is a location', () {
      final withMap = WatermarkPainter(
        content: content(place: _place()),
        config: const WatermarkConfig(template: WatermarkTemplate.map),
        imageSize: const Size(1080, 1920),
        reserveMapSlot: true,
      );
      expect(withMap.mapRect, isNotNull);
      expect(withMap.bounds.contains(withMap.mapRect!.center), isTrue);
      expect(
        (Offset.zero & const Size(1080, 1920)).intersect(withMap.bounds),
        withMap.bounds,
      );

      final noLocation = WatermarkPainter(
        content: content(
          location: const LocationSnapshot.unavailable(
            LocationUnavailableReason.permissionDenied,
          ),
        ),
        config: const WatermarkConfig(template: WatermarkTemplate.map),
        imageSize: const Size(1080, 1920),
        reserveMapSlot: true,
      );
      expect(noLocation.mapRect, isNull, reason: 'never a map without a fix');

      final noImage = WatermarkPainter(
        content: content(place: _place()),
        config: const WatermarkConfig(template: WatermarkTemplate.map),
        imageSize: const Size(1080, 1920),
      );
      expect(noImage.mapRect, isNull, reason: 'no snapshot, no map column');
      withMap.dispose();
      noLocation.dispose();
      noImage.dispose();
    });
  });

  group('capture post-processing', () {
    late Directory root;
    late PhotoStorageService storage;
    late WatermarkSettingsStore settings;
    late SavedCapture saved;
    final png = Uint8List.fromList(_tinyPng);

    setUpAll(() async {
      await mockPathProvider();
      await GetStorage.init('enrich_test');
    });

    setUp(() async {
      root = await mockPathProvider();
      storage = PhotoStorageService();
      final box = GetStorage('enrich_test');
      await box.erase();
      settings = WatermarkSettingsStore(StorageService(box));
      await settings.save(
        const WatermarkConfig(template: WatermarkTemplate.map),
      );
      final photos = await storage.photosDirectory();
      final photo = writeTestJpeg('${photos.path}/IMG_cap.jpg');
      final metadata = fixtureMetadata();
      final sidecar = await storage.saveMetadata(photo, metadata.toJson());
      saved = SavedCapture(
        photo: photo,
        metadata: metadata,
        metadataFile: sidecar,
      );
    });

    tearDown(Get.reset);

    CaptureEnricher enricher({PlaceInfo? place}) => CaptureEnricher(
      storage: storage,
      renderer: WatermarkRenderer(storage, rasterize: _blankOverlay),
      settings: settings,
      placeFor: (_) async => place,
      grabMap: () async => png,
      imageSize: (_) async => const Size(400, 300),
    );

    Map<String, dynamic> sidecar() =>
        jsonDecode(storage.metadataFileFor(saved.photo).readAsStringSync())
            as Map<String, dynamic>;

    test(
      'saves the map, adds the place and makes a watermarked copy',
      () async {
        final originalBytes = saved.photo.readAsBytesSync();
        final before = saved.metadata.toJson();

        final message = await enricher(place: _place()).process(saved, png);

        expect(message!.message, 'Watermarked copy saved');
        expect(message.isError, isFalse);
        expect(
          File('${root.path}/GPSCamera/Maps/IMG_cap_map.png').readAsBytesSync(),
          png,
        );
        final json = sidecar();
        expect(json['mapImageFileName'], 'IMG_cap_map.png');
        expect((json['place'] as Map)['locality'], 'Tongi');
        expect(json['capturedAt'], before['capturedAt']);
        expect(json['location'], before['location']);
        expect(
          File('${root.path}/GPSCamera/Watermarked/IMG_cap_wm.jpg')
              .existsSync(),
          isTrue,
        );
        expect(saved.photo.readAsBytesSync(), originalBytes);
      },
    );

    test('with auto watermark off, only place and map are added', () async {
      await settings.saveAutoWatermark(false);
      final message = await enricher(place: _place()).process(saved, png);

      expect(message, isNull);
      expect(sidecar()['place'], isNotNull);
      expect(
        Directory('${root.path}/GPSCamera/Watermarked').existsSync()
            ? Directory('${root.path}/GPSCamera/Watermarked').listSync()
            : const [],
        isEmpty,
      );
    });

    test('without a location there is no map and no place', () async {
      final noFix = fixtureMetadata(
        location: const LocationSnapshot.unavailable(
          LocationUnavailableReason.noFixYet,
        ),
      );
      await storage.saveMetadata(saved.photo, noFix.toJson());
      final blind = SavedCapture(
        photo: saved.photo,
        metadata: noFix,
        metadataFile: saved.metadataFile,
      );

      final message = await enricher().process(blind, png);

      expect(message!.message, 'Watermarked copy saved');
      expect(sidecar()['place'], isNull);
      expect(sidecar()['mapImageFileName'], isNull);
      expect(
        File('${root.path}/GPSCamera/Maps/IMG_cap_map.png').existsSync(),
        isFalse,
      );
    });

    test('a failing map grab never throws', () async {
      final failing = CaptureEnricher(
        storage: storage,
        renderer: WatermarkRenderer(storage, rasterize: _blankOverlay),
        settings: settings,
        placeFor: (_) async => null,
        grabMap: () => throw StateError('no map'),
      );
      expect(await failing.grabMap(), isNull);
    });
  });

  test('PDF rows show the stored place, or say it is unavailable', () {
    ReportEntry entry(PlaceInfo place) => ReportEntry(
      fileName: 'IMG_1.jpg',
      originalAvailable: true,
      images: const [],
      metadata: fixtureMetadata().withPlace(place: place),
    );
    Map<String, String> rows(ReportEntry e) => {
      for (final (l, v, _) in reportEntryRows(e, ReportType.project)) l: v,
    };

    final found = rows(entry(_place()));
    expect(found['Place'], 'Tongi, Dhaka Division, Bangladesh');
    expect(found['Address'], startsWith('WC62+8CJ, Road'));
    expect(found['Plus Code'], '7MMGWC62+9C6');

    final offline = rows(
      entry(
        PlaceInfo(
          latitude: 1,
          longitude: 2,
          plusCode: '6FG22222+22',
          resolvedAt: DateTime.utc(2026),
        ),
      ),
    );
    expect(offline['Address'], 'Unavailable (no address found)');
    expect(offline.containsKey('Place'), isFalse);
  });
}

Future<OverlayBitmap?> _blankOverlay(WatermarkPainter painter) async {
  final b = painter.bounds;
  final w = b.width.ceil();
  final h = b.height.ceil();
  return OverlayBitmap(
    left: b.left.floor(),
    top: b.top.floor(),
    width: w,
    height: h,
    rgba: Uint8List(w * h * 4),
  );
}

/// A valid 1×1 PNG.
const List<int> _tinyPng = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x60,
  0x00,
  0x02,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0xE2,
  0x26,
  0x05,
  0x9B,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
