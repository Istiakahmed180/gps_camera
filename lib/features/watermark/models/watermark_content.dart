import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/utils/location_formatter.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/utils/capture_time_formatter.dart';

/// How the recorded location may be presented.
enum WatermarkLocationState { current, lastKnown, unavailable }

/// The text a watermark may show, derived only from a photo's metadata and
/// the user's visibility settings. Template-independent.
///
/// Altitude is intentionally never included: on Android it is ellipsoid
/// height, not height above sea level.
class WatermarkContent {
  const WatermarkContent({
    this.date,
    this.time,
    this.timeZone,
    this.locationState,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.accuracyLevel,
    this.fixAge,
    this.address,
  });

  factory WatermarkContent.from(
    PhotoMetadata metadata,
    WatermarkConfig config,
  ) {
    final wallClock = CaptureTimeFormatter.wallClock(
      metadata.capturedAt,
      metadata.timeZoneOffset,
    );
    final location = metadata.location;
    final fix = location.fix;
    final showsLocation =
        config.showCoordinates ||
        config.showAccuracy ||
        (config.showAddress && fix?.address != null);

    final state = switch (location.status) {
      _ when !showsLocation => null,
      LocationRecordStatus.current when fix != null =>
        WatermarkLocationState.current,
      LocationRecordStatus.stale when fix != null =>
        WatermarkLocationState.lastKnown,
      _ => WatermarkLocationState.unavailable,
    };
    final hasFix = fix != null && state != WatermarkLocationState.unavailable;
    final address = fix?.address?.trim();

    return WatermarkContent(
      date: config.showDate ? CaptureTimeFormatter.date(wallClock) : null,
      time: config.showTime ? CaptureTimeFormatter.time(wallClock) : null,
      timeZone: config.showTime
          ? CaptureTimeFormatter.utcOffset(metadata.timeZoneOffset)
          : null,
      locationState: state,
      latitude: hasFix && config.showCoordinates
          ? LocationFormatter.latitude(fix.latitude)
          : null,
      longitude: hasFix && config.showCoordinates
          ? LocationFormatter.longitude(fix.longitude)
          : null,
      accuracy: hasFix && config.showAccuracy
          ? LocationFormatter.accuracy(fix.accuracy)
          : null,
      accuracyLevel: hasFix && config.showAccuracy
          ? GpsAccuracyLevel.fromMeters(fix.accuracy)
          : null,
      fixAge: state == WatermarkLocationState.lastKnown
          ? location.fixAge
          : null,
      address:
          hasFix && config.showAddress && address != null && address.isNotEmpty
          ? address
          : null,
    );
  }

  final String? date;
  final String? time;
  final String? timeZone;

  /// Null when every location field is hidden.
  final WatermarkLocationState? locationState;
  final String? latitude;
  final String? longitude;
  final String? accuracy;
  final GpsAccuracyLevel? accuracyLevel;

  /// How long before capture the last known fix was taken.
  final Duration? fixAge;
  final String? address;

  bool get hasDateTime => date != null || time != null;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get isEmpty => !hasDateTime && locationState == null;

  /// `07 Nov 2026 | 10:02 AM UTC+06:00`
  String? get dateTimeLine {
    final timePart = time == null ? null : '$time $timeZone';
    final parts = [?date, ?timePart];
    return parts.isEmpty ? null : parts.join('  |  ');
  }

  /// `23.910908° N, 90.401005° E`
  String? get coordinatesLine =>
      hasCoordinates ? '$latitude, $longitude' : null;

  /// `±6.8 m` with `(poor)` appended for poor fixes.
  String? get accuracyValue {
    if (accuracy == null) return null;
    return accuracyLevel == GpsAccuracyLevel.poor
        ? '$accuracy (poor)'
        : accuracy;
  }

  /// A caveat that must accompany the location, or null when current.
  String? get locationNotice => switch (locationState) {
    WatermarkLocationState.lastKnown =>
      fixAge == null
          ? 'Last known location'
          : 'Last known location · '
                '${CaptureTimeFormatter.age(fixAge!)} before capture',
    WatermarkLocationState.unavailable => 'Location unavailable',
    WatermarkLocationState.current || null => null,
  };
}
