import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/services/photo_exif.dart';
import 'package:gps_camera/features/location/controllers/compass_controller.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/location/models/camera_direction.dart';
import 'package:gps_camera/features/location/services/compass_service.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/reports/services/pdf_report_renderer.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/models/watermark_template.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';
import 'package:image/image.dart' as img;

import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

class _FakeCompass extends CompassService {
  _FakeCompass({this.available = true});

  final bool available;
  final controller = StreamController<CompassReading>.broadcast();
  int declinationCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<CompassReading> readings() => controller.stream;

  @override
  Future<double?> declination(
    double latitude,
    double longitude, {
    double altitude = 0,
  }) async {
    declinationCalls++;
    return -0.5;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('CameraDirection', () {
    test('labels with cardinal points and marks rough readings', () {
      expect(const CameraDirection(degrees: 0).label, '0° N');
      expect(const CameraDirection(degrees: 44.6).label, '45° NE');
      expect(const CameraDirection(degrees: 359.7).label, '0° N');
      expect(const CameraDirection(degrees: 202).cardinal, 'S');
      expect(const CameraDirection(degrees: 225).cardinal, 'SW');
      expect(const CameraDirection(degrees: 90, accuracy: 35).label, '≈90° E');
      expect(
        const CameraDirection(
          degrees: 90,
          accuracy: 12,
          trueNorth: false,
        ).description,
        '90° E (magnetic north, ±12°)',
      );
      expect(CameraDirection.normalize(-30), 330);
    });

    test('round-trips and stays optional in the sidecar', () {
      const d = CameraDirection(degrees: 45.5, accuracy: 8, flat: true);
      expect(CameraDirection.fromJson(d.toJson()), d);
      expect(fixtureMetadata().toJson().containsKey('direction'), isFalse);

      final withDir = PhotoMetadata.fromJson({
        ...fixtureMetadata().toJson(),
        'direction': d.toJson(),
      });
      expect(withDir.direction, d);
      expect(withDir.withNote('x').direction, d);
      expect(withDir.withPlace().direction, d);
    });
  });

  group('CompassController', () {
    late _FakeCompass compass;
    late LocationController location;
    var front = false;
    var now = DateTime(2026, 11, 7, 12);

    CompassController build() => Get.put(
      CompassController(
        compass,
        location,
        isFrontCamera: () => front,
        clock: () => now,
      ),
    );

    setUp(() {
      compass = _FakeCompass();
      final permissions = FakePermissionService();
      location = LocationController(FakeLocationService(), permissions);
      front = false;
      now = DateTime(2026, 11, 7, 12);
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('corrects to true north, flips for the front lens', () async {
      location.fix.value = testFix(latitude: 23.91, longitude: 90.40);
      final c = build();
      await settle();
      expect(compass.declinationCalls, 1);

      c.onReading(const CompassReading(magneticDegrees: 10, accuracy: 9));
      expect(c.direction.value!.degrees, 9.5);
      expect(c.direction.value!.trueNorth, isTrue);
      expect(c.snapshot(), c.direction.value);

      front = true;
      c.onReading(const CompassReading(magneticDegrees: 10));
      expect(c.direction.value!.degrees, 189.5);
      // Flat: the top edge is used, which is the same for both lenses.
      c.onReading(const CompassReading(magneticDegrees: 10, flat: true));
      expect(c.direction.value!.degrees, 9.5);

      // Moving a few km does not ask again; 30 km does.
      location.fix.value = testFix(latitude: 23.93, longitude: 90.40);
      await settle();
      expect(compass.declinationCalls, 1);
      location.fix.value = testFix(latitude: 24.2, longitude: 90.40);
      await settle();
      expect(compass.declinationCalls, 2);
    });

    test('magnetic only without a location; nothing when unreliable or '
        'stale', () async {
      final c = build();
      await settle();
      c.onReading(const CompassReading(magneticDegrees: 100, accuracy: 15));
      expect(c.direction.value!.trueNorth, isFalse);

      now = now.add(const Duration(seconds: 3));
      expect(c.snapshot(), isNull, reason: 'too old for a photo');

      c.onReading(const CompassReading(magneticDegrees: 100, accuracy: 70));
      expect(c.direction.value, isNull);
      expect(c.snapshot(), isNull);
    });

    test('stays off on phones without a compass', () async {
      compass = _FakeCompass(available: false);
      final c = build();
      await settle();
      expect(c.available.value, isFalse);
      expect(compass.controller.hasListener, isFalse);
    });

    test('the sensor stops while the app is in the background', () async {
      final c = build();
      await settle();
      expect(compass.controller.hasListener, isTrue);
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      await settle();
      expect(compass.controller.hasListener, isFalse);
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(compass.controller.hasListener, isTrue);
    });
  });

  group('shown and saved', () {
    final metadata = PhotoMetadata.fromJson({
      ...fixtureMetadata().toJson(),
      'direction': const CameraDirection(degrees: 44.6, accuracy: 9).toJson(),
    });

    test('watermark shows it in every template unless hidden', () {
      for (final template in WatermarkTemplate.values) {
        // Card templates share a line between accuracy and direction, so
        // accuracy is hidden to see the direction line come and go.
        final config = WatermarkConfig(template: template, showAccuracy: false);
        final content = WatermarkContent.from(metadata, config);
        expect(content.direction, '45° NE');
        final on = WatermarkPainter(
          content: content,
          config: config,
          imageSize: const Size(2000, 1500),
        );
        final offConfig = config.copyWith(showDirection: false);
        final off = WatermarkPainter(
          content: WatermarkContent.from(metadata, offConfig),
          config: offConfig,
          imageSize: const Size(2000, 1500),
        );
        expect(
          on.bounds.height,
          greaterThan(off.bounds.height),
          reason: template.name,
        );
        on.dispose();
        off.dispose();
      }
      expect(
        WatermarkConfig.fromJson({'template': 'map'}).showDirection,
        isTrue,
      );
    });

    test('reports list it', () {
      final rows = {
        for (final (l, v, _) in reportEntryRows(
          ReportEntry(
            fileName: 'IMG_1.jpg',
            originalAvailable: true,
            images: const [],
            metadata: metadata,
          ),
          ReportType.project,
        ))
          l: v,
      };
      expect(rows['Camera direction'], '45° NE (true north, ±9°)');
    });

    test('EXIF carries GPSImgDirection, but not for a flat phone', () {
      final jpeg = img.encodeJpg(img.Image(width: 8, height: 8));
      final exif = img.decodeJpgExif(
        PhotoExif.apply(jpeg, ExifSpec.from(metadata), upright: true)!,
      )!;
      expect(exif.gpsIfd[0x10].toString(), contains('T'));
      expect(exif.gpsIfd[0x11]!.toRational().toDouble(), 44.6);

      final flat = PhotoMetadata.fromJson({
        ...fixtureMetadata().toJson(),
        'direction': const CameraDirection(degrees: 10, flat: true).toJson(),
      });
      final flatExif = img.decodeJpgExif(
        PhotoExif.apply(jpeg, ExifSpec.from(flat), upright: true)!,
      )!;
      expect(flatExif.gpsIfd.containsKey(0x11), isFalse);
      expect(Uint8List(0), isEmpty);
    });
  });
}
