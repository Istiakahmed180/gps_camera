import 'package:get/get.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/utils/location_formatter.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/utils/capture_time_formatter.dart';

/// How the recorded location may be presented.
enum WatermarkLocationState { current, lastKnown, unavailable }

/// The text a watermark may show, derived only from a photo's metadata and
/// the user's visibility settings. Template-independent.
///
/// Altitude is shown only above mean sea level: an ellipsoid height (what
/// older Android phones report) can be tens of meters off.
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
    this.placeTitle,
    this.flag,
    this.plusCode,
    this.brand,
    this.customText,
    this.note,
    this.direction,
    this.altitude,
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
        (config.showAddress &&
            (fix?.address != null || metadata.place?.hasAddress == true));

    final state = switch (location.status) {
      _ when !showsLocation => null,
      LocationRecordStatus.current when fix != null =>
        WatermarkLocationState.current,
      LocationRecordStatus.stale when fix != null =>
        WatermarkLocationState.lastKnown,
      _ => WatermarkLocationState.unavailable,
    };
    final hasFix = fix != null && state != WatermarkLocationState.unavailable;
    final place = metadata.place;
    final address = (place?.addressLine ?? fix?.address)?.trim();

    return WatermarkContent(
      date: config.showDate ? CaptureTimeFormatter.date(wallClock) : null,
      // A video's stamp ticks every second.
      time: config.showTime
          ? CaptureTimeFormatter.time(wallClock, seconds: metadata.isVideo)
          : null,
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
      placeTitle: hasFix && config.showAddress ? place?.title : null,
      flag: hasFix && config.showAddress ? place?.flag : null,
      plusCode: hasFix && config.showCoordinates ? place?.plusCode : null,
      brand: config.brandText.isEmpty ? null : config.brandText,
      customText: config.customText.isEmpty ? null : config.customText,
      note: config.showNote ? metadata.note : null,
      direction: config.showDirection ? metadata.direction?.label : null,
      altitude:
          hasFix &&
              config.showAltitude &&
              fix.altitude != null &&
              fix.altitudeReference == AltitudeReference.meanSeaLevel
          ? LocationFormatter.length(fix.altitude!)
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

  /// `Tongi, Dhaka Division, Bangladesh`, from the looked-up place.
  final String? placeTitle;

  /// Country flag emoji for [placeTitle].
  final String? flag;

  /// Offline Plus Code for the capture location.
  final String? plusCode;

  /// Heading text; null when the user cleared it.
  final String? brand;

  /// The user's extra line, e.g. site or inspector name.
  final String? customText;

  /// The photo's own note.
  final String? note;

  /// `45° NE`: which way the camera faced.
  final String? direction;

  /// `34 m`: height above mean sea level.
  final String? altitude;

  /// `Alt 34 m`, translated.
  String? get altitudeLine =>
      altitude == null ? null : 'Alt @value'.trParams({'value': altitude!});

  /// Everything the stamp shows, so two moments of a video that would look
  /// the same can share one image.
  String get signature => [
    date,
    time,
    timeZone,
    locationState?.name,
    latitude,
    longitude,
    accuracy,
    accuracyLevel?.name,
    fixAge?.inSeconds,
    address,
    placeTitle,
    flag,
    plusCode,
    brand,
    customText,
    note,
    direction,
    altitude,
  ].join('\u0000');

  /// True when a map of the capture location may be shown.
  bool get canShowMap =>
      locationState != null &&
      locationState != WatermarkLocationState.unavailable;

  bool get hasDateTime => date != null || time != null;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Nothing about the photo itself to show. A heading or extra line alone
  /// is not a watermark worth saving.
  bool get isEmpty => !hasDateTime && locationState == null && note == null;

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
        ? '@accuracy (poor)'.trParams({'accuracy': '$accuracy'})
        : accuracy;
  }

  /// A caveat that must accompany the location, or null when current.
  String? get locationNotice => switch (locationState) {
    WatermarkLocationState.lastKnown =>
      fixAge == null
          ? 'Last known location'.tr
          : 'Last known location · @age before capture'.trParams({
              'age': CaptureTimeFormatter.age(fixAge!),
            }),
    WatermarkLocationState.unavailable => 'Location unavailable'.tr,
    WatermarkLocationState.current || null => null,
  };
}
