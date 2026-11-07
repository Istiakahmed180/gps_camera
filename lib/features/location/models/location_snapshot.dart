import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';

/// Whether a capture's location can be trusted as current.
enum LocationRecordStatus { current, stale, unavailable }

/// Why no location was recorded.
enum LocationUnavailableReason {
  permissionDenied,
  locationServicesDisabled,
  noFixYet,
  gpsUnavailable,
}

/// The location state at a specific moment, as recorded with a photo.
class LocationSnapshot {
  const LocationSnapshot._({
    required this.status,
    this.fix,
    this.fixAge,
    this.reason,
  });

  const LocationSnapshot.current(LocationFix fix, Duration age)
    : this._(status: LocationRecordStatus.current, fix: fix, fixAge: age);

  const LocationSnapshot.stale(LocationFix fix, Duration age)
    : this._(status: LocationRecordStatus.stale, fix: fix, fixAge: age);

  const LocationSnapshot.unavailable(LocationUnavailableReason reason)
    : this._(status: LocationRecordStatus.unavailable, reason: reason);

  factory LocationSnapshot.fromJson(Map<String, dynamic> json) {
    final status = LocationRecordStatus.values.byName(json['status'] as String);
    final fixJson = json['fix'] as Map<String, dynamic>?;
    final ageMs = json['fixAgeMs'] as int?;
    final reason = json['reason'] as String?;

    return LocationSnapshot._(
      status: status,
      fix: fixJson == null ? null : LocationFix.fromJson(fixJson),
      fixAge: ageMs == null ? null : Duration(milliseconds: ageMs),
      reason: reason == null
          ? null
          : LocationUnavailableReason.values.byName(reason),
    );
  }

  final LocationRecordStatus status;
  final LocationFix? fix;

  /// Time between the fix and the moment this snapshot was taken.
  final Duration? fixAge;
  final LocationUnavailableReason? reason;

  GpsAccuracyLevel? get accuracyLevel {
    final current = fix;
    return current == null
        ? null
        : GpsAccuracyLevel.fromMeters(current.accuracy);
  }

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'reason': reason?.name,
    'accuracyLevel': accuracyLevel?.name,
    'fixAgeMs': fixAge?.inMilliseconds,
    'fix': fix?.toJson(),
  };
}
