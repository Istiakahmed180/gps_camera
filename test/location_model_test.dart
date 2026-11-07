import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/services/location_service.dart';
import 'package:gps_camera/features/location/utils/location_formatter.dart';

Position _position({
  double latitude = 51.5007292,
  double longitude = -0.1246254,
  double accuracy = 6.5,
  bool hasAccuracy = true,
  bool hasAltitude = true,
  bool hasHeading = false,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.utc(2026, 11, 7, 9, 30),
    accuracy: accuracy,
    altitude: 35.25,
    altitudeAccuracy: 3,
    heading: 270,
    headingAccuracy: 5,
    speed: 0,
    speedAccuracy: 0,
    hasAccuracy: hasAccuracy,
    hasAltitude: hasAltitude,
    hasAltitudeAccuracy: hasAltitude,
    hasHeading: hasHeading,
  );
}

void main() {
  group('LocationFix JSON', () {
    test('round-trips every field without rounding', () {
      final fix = LocationFix(
        latitude: 37.42199834567,
        longitude: -122.08400012345,
        accuracy: 3.79,
        timestamp: DateTime.utc(2026, 11, 7, 9, 30, 1, 250),
        altitude: 12.3456,
        altitudeReference: AltitudeReference.meanSeaLevel,
        altitudeAccuracy: 2.5,
        heading: 181.5,
        isMocked: true,
        address: '1 Example Road',
      );

      final json = fix.toJson();
      expect(json['latitude'], 37.42199834567);
      expect(json['timestamp'], '2026-11-07T09:30:01.250Z');
      expect(LocationFix.fromJson(json), fix);
    });

    test('round-trips a fix with no optional values', () {
      final fix = LocationFix(
        latitude: -33.8568,
        longitude: 151.2153,
        accuracy: 25,
        timestamp: DateTime.utc(2026, 1, 2),
      );

      final json = fix.toJson();
      expect(json['altitude'], isNull);
      expect(json['heading'], isNull);
      expect(json['address'], isNull);
      expect(LocationFix.fromJson(json), fix);
    });
  });

  group('LocationService.toFix', () {
    test('maps a valid position exactly', () {
      final fix = LocationService.toFix(_position())!;
      expect(fix.latitude, 51.5007292);
      expect(fix.longitude, -0.1246254);
      expect(fix.accuracy, 6.5);
      expect(fix.altitude, 35.25);
      expect(fix.altitudeReference, isNotNull);
      expect(fix.timestamp.isUtc, isTrue);
    });

    test('omits altitude and heading the platform did not measure', () {
      final fix = LocationService.toFix(_position(hasAltitude: false))!;
      expect(fix.altitude, isNull);
      expect(fix.altitudeReference, isNull);
      expect(fix.altitudeAccuracy, isNull);
      expect(fix.heading, isNull);
    });

    test('keeps heading only when reported', () {
      expect(LocationService.toFix(_position(hasHeading: true))!.heading, 270);
    });

    test('rejects fixes without accuracy or with invalid coordinates', () {
      expect(LocationService.toFix(_position(hasAccuracy: false)), isNull);
      expect(LocationService.toFix(_position(latitude: double.nan)), isNull);
      expect(LocationService.toFix(_position(longitude: 200)), isNull);
      expect(LocationService.toFix(_position(accuracy: -1)), isNull);
    });

    test('maps platform errors to location error kinds', () {
      expect(
        LocationService.mapError(const LocationServiceDisabledException()).kind,
        LocationErrorKind.serviceDisabled,
      );
      expect(
        LocationService.mapError(const PermissionDeniedException('no')).kind,
        LocationErrorKind.permissionDenied,
      );
      expect(
        LocationService.mapError(Exception('boom')).kind,
        LocationErrorKind.unavailable,
      );
    });
  });

  test('accuracy bands use 10 m and 30 m boundaries', () {
    expect(GpsAccuracyLevel.fromMeters(0), GpsAccuracyLevel.good);
    expect(GpsAccuracyLevel.fromMeters(10), GpsAccuracyLevel.good);
    expect(GpsAccuracyLevel.fromMeters(10.1), GpsAccuracyLevel.moderate);
    expect(GpsAccuracyLevel.fromMeters(30), GpsAccuracyLevel.moderate);
    expect(GpsAccuracyLevel.fromMeters(30.1), GpsAccuracyLevel.poor);
  });

  test('snapshot JSON round-trips', () {
    final fix = LocationFix(
      latitude: 1,
      longitude: 2,
      accuracy: 45,
      timestamp: DateTime.utc(2026),
    );
    final stale = LocationSnapshot.stale(fix, const Duration(seconds: 90));
    final json = stale.toJson();

    expect(json['status'], 'stale');
    expect(json['accuracyLevel'], 'poor');
    expect(json['fixAgeMs'], 90000);

    final restored = LocationSnapshot.fromJson(json);
    expect(restored.status, LocationRecordStatus.stale);
    expect(restored.fix, fix);
    expect(restored.fixAge, const Duration(seconds: 90));
  });

  test('formatter shows hemispheres and does not flatter accuracy', () {
    expect(LocationFormatter.latitude(-33.8568), '33.856800° S');
    expect(LocationFormatter.longitude(-122.084), '122.084000° W');
    expect(LocationFormatter.accuracy(4.26), '±4.3 m');
    expect(LocationFormatter.accuracy(45.6), '±46 m');
    expect(
      LocationFormatter.altitude(12.4, AltitudeReference.wgs84Ellipsoid),
      'Alt 12 m WGS84',
    );
  });
}
