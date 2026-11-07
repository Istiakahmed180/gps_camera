import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/utils/capture_time_formatter.dart';

import 'helpers/watermark_fixtures.dart';

void main() {
  const config = WatermarkConfig();

  group('metadata parsing', () {
    test('reads a real device sidecar without losing fields', () {
      final json = jsonDecode(phoneSidecarJson) as Map<String, dynamic>;
      final metadata = PhotoMetadata.fromJson(json);

      expect(metadata.imageFileName, 'IMG_20261107_100209_588.jpg');
      expect(metadata.timeZoneOffset, const Duration(hours: 6));
      expect(metadata.location.status, LocationRecordStatus.current);
      final fix = metadata.location.fix!;
      expect(fix.accuracy, 6.752999782562256);
      expect(fix.altitude, -26.100000381469727);
      expect(fix.altitudeAccuracy, 3.834149122238159);

      final content = WatermarkContent.from(metadata, config);
      expect(content.date, '07 Nov 2026');
      expect(content.time, '10:02 AM');
      expect(content.timeZone, 'UTC+06:00');
      expect(content.latitude, '23.910908° N');
      expect(content.accuracyValue, '±6.8 m');
      expect(content.locationNotice, isNull);

      final reencoded = metadata.toJson();
      expect(
        (reencoded['location'] as Map)['fix'],
        (json['location'] as Map)['fix'],
      );
    });
  });

  group('date and time', () {
    test('uses the capture time zone, not the device zone', () {
      final content = WatermarkContent.from(
        fixtureMetadata(
          capturedAt: DateTime.utc(2026, 11, 7, 2),
          offset: const Duration(hours: -5),
        ),
        config,
      );
      expect(content.date, '06 Nov 2026');
      expect(content.time, '09:00 PM');
      expect(content.timeZone, 'UTC-05:00');
    });

    test('formats half-hour offsets, midnight and noon', () {
      expect(
        CaptureTimeFormatter.utcOffset(const Duration(hours: -3, minutes: -30)),
        'UTC-03:30',
      );
      expect(
        CaptureTimeFormatter.utcOffset(const Duration(hours: 5, minutes: 45)),
        'UTC+05:45',
      );
      expect(CaptureTimeFormatter.utcOffset(Duration.zero), 'UTC');
      expect(CaptureTimeFormatter.time(DateTime.utc(2026, 1, 2)), '12:00 AM');
      expect(
        CaptureTimeFormatter.time(DateTime.utc(2026, 1, 1, 12, 5)),
        '12:05 PM',
      );
    });

    test('date line joins only the visible parts', () {
      final dateOnly = WatermarkContent.from(
        fixtureMetadata(),
        config.copyWith(showTime: false),
      );
      expect(dateOnly.dateTimeLine, '07 Nov 2026');
      expect(dateOnly.timeZone, isNull);
    });
  });

  group('location', () {
    test('missing location never shows coordinates', () {
      final content = WatermarkContent.from(
        fixtureMetadata(
          location: const LocationSnapshot.unavailable(
            LocationUnavailableReason.permissionDenied,
          ),
        ),
        config,
      );
      expect(content.locationState, WatermarkLocationState.unavailable);
      expect(content.locationNotice, 'Location unavailable');
      expect(content.coordinatesLine, isNull);
      expect(content.accuracyValue, isNull);
    });

    test('stale location is labelled as last known with its age', () {
      final content = WatermarkContent.from(
        fixtureMetadata(
          location: LocationSnapshot.stale(
            fixtureFix(),
            const Duration(minutes: 5, seconds: 12),
          ),
        ),
        config,
      );
      expect(content.locationState, WatermarkLocationState.lastKnown);
      expect(
        content.locationNotice,
        'Last known location · 5 min before capture',
      );
      expect(content.coordinatesLine, '23.910908° N, 90.401005° E');
    });

    test('poor accuracy shows the real value and says poor', () {
      final content = WatermarkContent.from(
        fixtureMetadata(
          location: LocationSnapshot.current(
            fixtureFix(accuracy: 789.73),
            Duration.zero,
          ),
        ),
        config,
      );
      expect(content.accuracyLevel, GpsAccuracyLevel.poor);
      expect(content.accuracyValue, '±790 m (poor)');
    });

    test('address appears only when recorded and enabled', () {
      final none = WatermarkContent.from(fixtureMetadata(), config);
      expect(none.address, isNull);

      final withAddress = fixtureMetadata(
        location: LocationSnapshot.current(
          fixtureFix(address: ' 12 Site Road '),
          Duration.zero,
        ),
      );
      expect(
        WatermarkContent.from(withAddress, config).address,
        '12 Site Road',
      );
      expect(
        WatermarkContent.from(
          withAddress,
          config.copyWith(showAddress: false),
        ).address,
        isNull,
      );
    });

    test('hiding location fields removes the location entirely', () {
      final content = WatermarkContent.from(
        fixtureMetadata(),
        config.copyWith(showCoordinates: false, showAccuracy: false),
      );
      expect(content.locationState, isNull);
      expect(content.coordinatesLine, isNull);
    });

    test('everything hidden means nothing to render', () {
      final content = WatermarkContent.from(
        fixtureMetadata(),
        const WatermarkConfig(
          showDate: false,
          showTime: false,
          showCoordinates: false,
          showAccuracy: false,
          showAddress: false,
        ),
      );
      expect(content.isEmpty, isTrue);
    });
  });
}
