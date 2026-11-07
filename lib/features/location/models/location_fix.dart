/// What [LocationFix.altitude] is measured from. Android reports height
/// above the WGS84 ellipsoid; iOS reports height above mean sea level.
enum AltitudeReference { wgs84Ellipsoid, meanSeaLevel }

/// A single GPS fix exactly as reported by the platform.
///
/// Values are stored unrounded; formatting happens only in the UI.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.altitude,
    this.altitudeReference,
    this.altitudeAccuracy,
    this.heading,
    this.isMocked = false,
    this.address,
  });

  factory LocationFix.fromJson(Map<String, dynamic> json) {
    return LocationFix(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      altitude: (json['altitude'] as num?)?.toDouble(),
      altitudeReference: switch (json['altitudeReference']) {
        final String name => AltitudeReference.values.byName(name),
        _ => null,
      },
      altitudeAccuracy: (json['altitudeAccuracy'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      isMocked: json['isMocked'] as bool? ?? false,
      address: json['address'] as String?,
    );
  }

  /// Degrees, WGS84.
  final double latitude;

  /// Degrees, WGS84.
  final double longitude;

  /// Estimated horizontal accuracy radius in meters.
  final double accuracy;

  /// Time of the fix (UTC).
  final DateTime timestamp;

  /// Meters, when the fix includes it. See [altitudeReference].
  final double? altitude;

  /// Set whenever [altitude] is present.
  final AltitudeReference? altitudeReference;

  /// Estimated vertical accuracy in meters, when available.
  final double? altitudeAccuracy;

  /// Direction of travel in degrees from true north, only when the platform
  /// reports one. This is not a compass heading.
  final double? heading;

  /// True when the platform flags the fix as coming from a mock provider.
  final bool isMocked;

  /// Human-readable address. Not populated until reverse geocoding exists.
  final String? address;

  Duration ageAt(DateTime time) {
    final age = time.difference(timestamp);
    return age.isNegative ? Duration.zero : age;
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'altitude': altitude,
    'altitudeReference': altitudeReference?.name,
    'altitudeAccuracy': altitudeAccuracy,
    'heading': heading,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'isMocked': isMocked,
    'address': address,
  };

  @override
  bool operator ==(Object other) =>
      other is LocationFix &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracy == accuracy &&
      other.timestamp == timestamp &&
      other.altitude == altitude &&
      other.altitudeReference == altitudeReference &&
      other.altitudeAccuracy == altitudeAccuracy &&
      other.heading == heading &&
      other.isMocked == isMocked &&
      other.address == address;

  @override
  int get hashCode => Object.hash(
    latitude,
    longitude,
    accuracy,
    timestamp,
    altitude,
    altitudeReference,
    altitudeAccuracy,
    heading,
    isMocked,
    address,
  );
}
