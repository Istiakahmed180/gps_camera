/// What a location is called, from the device's reverse geocoder, plus an
/// offline Plus Code. Describes [latitude]/[longitude] as of [resolvedAt].
class PlaceInfo {
  const PlaceInfo({
    required this.latitude,
    required this.longitude,
    required this.plusCode,
    required this.resolvedAt,
    this.addressLine,
    this.subLocality,
    this.locality,
    this.subAdministrativeArea,
    this.administrativeArea,
    this.postalCode,
    this.country,
    this.countryCode,
  });

  factory PlaceInfo.fromJson(Map<String, dynamic> json) => PlaceInfo(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    plusCode: json['plusCode'] as String,
    resolvedAt: DateTime.parse(json['resolvedAt'] as String),
    addressLine: json['addressLine'] as String?,
    subLocality: json['subLocality'] as String?,
    locality: json['locality'] as String?,
    subAdministrativeArea: json['subAdministrativeArea'] as String?,
    administrativeArea: json['administrativeArea'] as String?,
    postalCode: json['postalCode'] as String?,
    country: json['country'] as String?,
    countryCode: json['countryCode'] as String?,
  );

  /// The coordinates this place was looked up for.
  final double latitude;
  final double longitude;

  /// Always present: computed offline from the coordinates.
  final String plusCode;
  final DateTime resolvedAt;

  /// Full single-line address from the geocoder; null when it had none
  /// (e.g. offline).
  final String? addressLine;
  final String? subLocality;
  final String? locality;
  final String? subAdministrativeArea;
  final String? administrativeArea;
  final String? postalCode;
  final String? country;

  /// ISO 3166-1 alpha-2, e.g. `BD`.
  final String? countryCode;

  /// The same place described at nearby [lat]/[lng]: the address is kept
  /// (geocoders resolve to the nearest address anyway) and the Plus Code is
  /// recomputed for the exact point.
  PlaceInfo at(double lat, double lng, String plusCode) => PlaceInfo(
    latitude: lat,
    longitude: lng,
    plusCode: plusCode,
    resolvedAt: resolvedAt,
    addressLine: addressLine,
    subLocality: subLocality,
    locality: locality,
    subAdministrativeArea: subAdministrativeArea,
    administrativeArea: administrativeArea,
    postalCode: postalCode,
    country: country,
    countryCode: countryCode,
  );

  bool get hasAddress =>
      addressLine != null || locality != null || country != null;

  /// `Tongi, Dhaka Division, Bangladesh`
  String? get title {
    final parts = <String>[];
    for (final part in [
      locality ?? subAdministrativeArea ?? subLocality,
      administrativeArea,
      country,
    ]) {
      if (part != null && part.trim().isNotEmpty && !parts.contains(part)) {
        parts.add(part.trim());
      }
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Country flag emoji from [countryCode], or null.
  String? get flag {
    final code = countryCode?.toUpperCase();
    if (code == null || !RegExp(r'^[A-Z]{2}$').hasMatch(code)) return null;
    return String.fromCharCodes(code.codeUnits.map((c) => 0x1F1E6 + c - 65));
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'plusCode': plusCode,
    'resolvedAt': resolvedAt.toUtc().toIso8601String(),
    'addressLine': addressLine,
    'subLocality': subLocality,
    'locality': locality,
    'subAdministrativeArea': subAdministrativeArea,
    'administrativeArea': administrativeArea,
    'postalCode': postalCode,
    'country': country,
    'countryCode': countryCode,
  };
}
