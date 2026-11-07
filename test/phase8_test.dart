import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/core/settings/app_preferences.dart';
import 'package:gps_camera/core/settings/display_format.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/models/photo_quality.dart';
import 'package:gps_camera/features/export/services/gallery_export_service.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/models/place_info.dart';
import 'package:gps_camera/features/location/services/details_backfill.dart';
import 'package:gps_camera/features/location/services/map_cache.dart';
import 'package:gps_camera/features/location/services/static_map_service.dart';
import 'package:gps_camera/features/location/utils/location_formatter.dart';
import 'package:gps_camera/features/settings/services/storage_usage.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/models/watermark_record.dart';
import 'package:gps_camera/features/watermark/models/watermark_template.dart';
import 'package:gps_camera/features/watermark/services/image_processor.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';
import 'package:gps_camera/features/watermark/utils/capture_time_formatter.dart';
import 'package:image/image.dart' as img;

import 'backup_and_gallery_export_test.dart' show FakePhoneGallery;
import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

final Uint8List _png = img.encodePng(img.Image(width: 8, height: 8));

PlaceInfo _place() => PlaceInfo(
  latitude: 23.910913,
  longitude: 90.401004,
  plusCode: '7MMGWC62+9C6',
  resolvedAt: DateTime.utc(2026, 11, 7, 9),
  addressLine: 'WC62+8CJ, Road, Tongi, Bangladesh',
  locality: 'Tongi',
  country: 'Bangladesh',
  countryCode: 'BD',
);

PlaceInfo _plusCodeOnly() => PlaceInfo(
  latitude: 23.910913,
  longitude: 90.401004,
  plusCode: '7MMGWC62+9C6',
  resolvedAt: DateTime.utc(2026, 11, 7, 9),
);

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    DisplayFormat.current = const DisplayFormat();
    Get.reset();
  });

  group('display format', () {
    final wall = DateTime.utc(2026, 11, 7, 14, 5);

    test('time follows the 12/24-hour choice', () {
      expect(CaptureTimeFormatter.time(wall), '02:05 PM');
      DisplayFormat.current = const DisplayFormat(use24Hour: true);
      expect(CaptureTimeFormatter.time(wall), '14:05');
      expect(
        CaptureTimeFormatter.time(DateTime.utc(2026, 1, 1, 0, 7)),
        '00:07',
      );
    });

    test('distances convert to feet only for display', () {
      expect(LocationFormatter.accuracy(6.9), '±6.9 m');
      expect(LocationFormatter.accuracy(16.4), '±16 m');
      DisplayFormat.current = const DisplayFormat(units: UnitSystem.imperial);
      expect(LocationFormatter.accuracy(6.9), '±22.6 ft');
      expect(LocationFormatter.accuracy(16.4), '±54 ft');
      expect(LocationFormatter.altitude(-26, null), 'Alt -85 ft');
      expect(PhotoInfoFormatter.length(1), '3.281 ft');
    });

    test('the watermark uses the current format', () {
      final metadata = fixtureMetadata();
      DisplayFormat.current = const DisplayFormat(
        use24Hour: true,
        units: UnitSystem.imperial,
      );
      final content = WatermarkContent.from(metadata, const WatermarkConfig());
      expect(content.time, '10:02');
      expect(content.accuracy, endsWith(' ft'));
    });

    test('round-trips through JSON with safe defaults', () {
      const format = DisplayFormat(use24Hour: true, units: UnitSystem.imperial);
      expect(DisplayFormat.fromJson(format.toJson()), format);
      expect(
        DisplayFormat.fromJson({'units': 'cubits'}),
        const DisplayFormat(),
      );
    });
  });

  group('preferences', () {
    setUpAll(() async {
      await mockPathProvider();
      await GetStorage.init('phase8_test');
    });

    test('photo quality and format persist and apply', () async {
      final box = GetStorage('phase8_test');
      await box.erase();
      final storage = StorageService(box);

      final prefs = AppPreferences(storage)..onInit();
      expect(prefs.photoQuality.value, PhotoQuality.high);
      expect(PhotoQuality.high.preset, ResolutionPreset.ultraHigh);

      await prefs.setPhotoQuality(PhotoQuality.maximum);
      await prefs.setDisplayFormat(const DisplayFormat(use24Hour: true));
      expect(DisplayFormat.current.use24Hour, isTrue);

      DisplayFormat.current = const DisplayFormat();
      final reloaded = AppPreferences(storage)..onInit();
      expect(reloaded.photoQuality.value, PhotoQuality.maximum);
      expect(DisplayFormat.current.use24Hour, isTrue);
      expect(PhotoQuality.parse('bogus'), PhotoQuality.high);
      expect(storage.read<String>(StorageKeys.photoQuality), 'maximum');
    });
  });

  group('map cache', () {
    late Directory dir;
    late MapCache cache;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('map_cache');
      cache = MapCache(baseDirectory: () async => dir, maxEntries: 3);
    });

    test('stores by rounded point and reports usage', () async {
      expect(await cache.read(23.91091, 90.40100, 16), isNull);
      await cache.write(23.91091, 90.40100, 16, _png);
      expect(await cache.read(23.910913, 90.401004, 16), _png);
      expect(await cache.read(23.9120, 90.40100, 16), isNull);
      expect(await cache.read(23.91091, 90.40100, 15), isNull);
      final (bytes, count) = await cache.usage();
      expect((bytes, count), (_png.length, 1));

      await cache.clear();
      expect((await cache.usage()).$2, 0);
    });

    test('keeps only the most recently used entries', () async {
      for (var i = 0; i < 3; i++) {
        await cache.write(10 + i.toDouble(), 20, 16, _png);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await cache.read(10, 20, 16); // touch the oldest
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await cache.write(13, 20, 16, _png);

      expect(await cache.read(10, 20, 16), isNotNull);
      expect(await cache.read(11, 20, 16), isNull);
      expect((await cache.usage()).$2, 3);
    });

    test('the map service answers from the cache without network', () async {
      await cache.write(23.9109, 90.4010, StaticMapService.zoom, _png);
      final client = HttpClient()..connectionTimeout = Duration.zero;
      final service = StaticMapService(
        'key',
        client: client,
        cache: cache,
        timeout: const Duration(milliseconds: 1),
      );
      expect(await service.fetch(23.9109, 90.4010), _png);
      expect(await service.fetch(1, 1), isNull, reason: 'not cached, offline');
    });
  });

  group('details backfill', () {
    late Directory root;
    late PhotoStorageService storage;
    late File original;
    late FakePhoneGallery phone;
    late StorageService settings;
    var describeCalls = 0;
    var mapCalls = 0;

    setUpAll(() async {
      await mockPathProvider();
      await GetStorage.init('phase8_backfill');
    });

    setUp(() async {
      root = await mockPathProvider();
      storage = PhotoStorageService();
      final box = GetStorage('phase8_backfill');
      await box.erase();
      settings = StorageService(box);
      phone = FakePhoneGallery();
      describeCalls = 0;
      mapCalls = 0;

      final photos = await storage.photosDirectory();
      original = writeTestJpeg('${photos.path}/IMG_off.jpg');
      final offline = fixtureMetadata().withPlace(place: _plusCodeOnly());
      await storage.saveMetadata(original, offline.toJson());
    });

    WatermarkRenderer renderer() =>
        WatermarkRenderer(storage, rasterize: _blankOverlay);

    Future<File> copy({required bool automatic}) async {
      final metadata = PhotoMetadata.fromJson(
        (await storage.readMetadata(original))!,
      );
      final result = await renderer().render(
        original: original,
        metadata: metadata,
        config: const WatermarkConfig(template: WatermarkTemplate.map),
        imageSize: const Size(400, 300),
        automatic: automatic,
      );
      return result.output;
    }

    DetailsBackfill backfill({
      PlaceInfo? place,
      Uint8List? map,
      bool maps = true,
    }) => DetailsBackfill(
      storage: storage,
      gallery: GalleryService(storage),
      describe: (lat, lng) async {
        describeCalls++;
        return place ?? _plusCodeOnly();
      },
      renderer: renderer(),
      fetchMap: maps
          ? (lat, lng) async {
              mapCalls++;
              return map;
            }
          : null,
      export: GalleryExportService(settings, phone),
      imageSize: (_) async => const Size(400, 300),
    );

    Map<String, dynamic> sidecar() =>
        jsonDecode(storage.metadataFileFor(original).readAsStringSync())
            as Map<String, dynamic>;

    List<String> copies() =>
        Directory('${root.path}/GPSCamera/Watermarked')
            .listSync()
            .map((f) => f.uri.pathSegments.last)
            .where((n) => n.endsWith('.jpg'))
            .toList()
          ..sort();

    test('adds address and map, remakes only automatic copies', () async {
      final originalBytes = original.readAsBytesSync();
      final before = sidecar();
      final auto = await copy(automatic: true);
      final edited = await copy(automatic: false);
      final editedBytes = edited.readAsBytesSync();
      expect(copies(), ['IMG_off_wm.jpg', 'IMG_off_wm_1.jpg']);

      final result = await backfill(place: _place(), map: _png).run();

      expect(result.updatedPhotos, 1);
      expect(result.replacedCopies, 1);
      expect(result.remaining, 0);

      final after = sidecar();
      expect((after['place'] as Map)['locality'], 'Tongi');
      expect(after['mapImageFileName'], 'IMG_off_map.png');
      expect(after['capturedAt'], before['capturedAt']);
      expect(after['location'], before['location']);
      expect(original.readAsBytesSync(), originalBytes);
      expect(
        File('${root.path}/GPSCamera/Maps/IMG_off_map.png').readAsBytesSync(),
        _png,
      );

      expect(auto.existsSync(), isFalse, reason: 'old automatic copy removed');
      expect(storage.metadataFileFor(auto).existsSync(), isFalse);
      expect(edited.readAsBytesSync(), editedBytes, reason: 'editor copy kept');
      expect(copies(), ['IMG_off_wm_1.jpg', 'IMG_off_wm_2.jpg']);

      final record = WatermarkRecord.fromJson(
        jsonDecode(
          File('${root.path}/GPSCamera/Watermarked/IMG_off_wm_2.json')
              .readAsStringSync(),
        ) as Map<String, dynamic>,
      );
      expect(record.automatic, isTrue);
      expect(record.sourceMetadata!.place!.locality, 'Tongi');
      expect(record.config.template, WatermarkTemplate.map);
      expect(phone.saved, ['IMG_off_wm_2.jpg']);

      final again = await backfill(place: _place(), map: _png).run();
      expect(again.updatedPhotos, 0);
      expect(describeCalls, 1, reason: 'complete photos are not looked up');
    });

    test('offline: changes nothing and stops early', () async {
      final auto = await copy(automatic: true);
      final before = storage.metadataFileFor(original).readAsStringSync();

      final result = await backfill().run();

      expect(result.updatedPhotos, 0);
      expect(result.remaining, 1);
      expect(storage.metadataFileFor(original).readAsStringSync(), before);
      expect(auto.existsSync(), isTrue);
      expect(phone.saved, isEmpty);
    });

    test('stops after two photos in a row get nothing', () async {
      final photos = await storage.photosDirectory();
      for (final name in ['IMG_a', 'IMG_b', 'IMG_c']) {
        final file = writeTestJpeg('${photos.path}/$name.jpg');
        await storage.saveMetadata(file, fixtureMetadata().toJson());
      }
      await backfill().run();
      expect(describeCalls, 2);
    });

    test('a map alone is still saved when there is no address', () async {
      final b = backfill(map: _png);
      final result = await b.run();
      expect(result.updatedPhotos, 1);
      expect(sidecar()['mapImageFileName'], 'IMG_off_map.png');
      expect(result.remaining, 1, reason: 'the address is still missing');

      // The map came back, so the phone is online and this spot simply has
      // no address: it is not asked again this session.
      final calls = describeCalls;
      await b.run();
      expect(describeCalls, calls);
    });

    test('photos without GPS are never looked up', () async {
      final photos = await storage.photosDirectory();
      final file = writeTestJpeg('${photos.path}/IMG_nogps.jpg');
      await storage.saveMetadata(
        file,
        fixtureMetadata(
          location: const LocationSnapshot.unavailable(
            LocationUnavailableReason.permissionDenied,
          ),
        ).toJson(),
      );
      await storage.saveMetadata(
        original,
        fixtureMetadata()
            .withPlace(place: _place(), mapImageFileName: 'x.png')
            .toJson(),
      );
      final result = await backfill(place: _place(), map: _png).run();
      expect(result.updatedPhotos, 0);
      expect(describeCalls, 0);
      expect(mapCalls, 0);
    });

    test('without a map key only the address is needed', () async {
      final result = await backfill(place: _place(), maps: false).run();
      expect(result.updatedPhotos, 1);
      expect(result.remaining, 0);
      expect(sidecar()['mapImageFileName'], isNull);
    });
  });

  test('storage usage adds up each folder', () async {
    final root = await mockPathProvider();
    final storage = PhotoStorageService();
    final photos = await storage.photosDirectory();
    File('${photos.path}/IMG_1.jpg').writeAsBytesSync(List.filled(100, 1));
    File('${photos.path}/IMG_1.json').writeAsBytesSync(List.filled(10, 1));
    final reports = await storage.reportsDirectory();
    File('${reports.path}/r.pdf').writeAsBytesSync(List.filled(50, 1));
    final cacheDir = await Directory.systemTemp.createTemp('usage_cache');
    final cache = MapCache(baseDirectory: () async => cacheDir);
    await cache.write(1, 2, 16, _png);

    final usage = await StorageUsage(storage, cache).measure();
    expect(usage.photos, 110);
    expect(usage.photoCount, 1);
    expect(usage.reports, 50);
    expect(usage.reportCount, 1);
    expect(usage.mapCacheCount, 1);
    expect(usage.total, 160 + _png.length);
    expect(root.existsSync(), isTrue);
  });

  test('watermark records remember automatic copies', () {
    final record = WatermarkRecord(
      outputFileName: 'a_wm.jpg',
      sourceImageFileName: 'a.jpg',
      sourceMetadataFileName: 'a.json',
      renderedAt: DateTime.utc(2026),
      imageWidth: 1,
      imageHeight: 1,
      config: const WatermarkConfig(),
      automatic: true,
    );
    expect(WatermarkRecord.fromJson(record.toJson()).automatic, isTrue);
    final json = record.toJson()..remove('automatic');
    expect(WatermarkRecord.fromJson(json).automatic, isFalse);
  });
}
