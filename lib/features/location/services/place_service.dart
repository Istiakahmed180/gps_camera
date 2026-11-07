import 'dart:async';
import 'dart:math' as math;

import 'package:geocoding/geocoding.dart';
import 'package:gps_camera/features/location/models/place_info.dart';
import 'package:gps_camera/features/location/utils/plus_code.dart';

typedef ReverseGeocoder = Future<List<Placemark>> Function(
  double latitude,
  double longitude,
);

/// Turns coordinates into a [PlaceInfo]: the Plus Code always (offline),
/// the address when the device geocoder can be reached. Never throws and
/// never invents an address.
class PlaceService {
  PlaceService({
    ReverseGeocoder? geocoder,
    this.timeout = const Duration(seconds: 8),
    DateTime Function()? clock,
  }) : _geocoder = geocoder ?? _platformGeocoder,
       _clock = clock ?? DateTime.now;

  final ReverseGeocoder _geocoder;
  final Duration timeout;
  final DateTime Function() _clock;

  Future<PlaceInfo> describe(double latitude, double longitude) async {
    Placemark? mark;
    try {
      final marks = await _geocoder(latitude, longitude).timeout(timeout);
      mark = marks.isEmpty ? null : marks.first;
    } catch (_) {
      mark = null;
    }
    String? clean(String? value) =>
        value == null || value.trim().isEmpty ? null : value.trim();

    return PlaceInfo(
      latitude: latitude,
      longitude: longitude,
      plusCode: PlusCode.encode(latitude, longitude),
      resolvedAt: _clock().toUtc(),
      // Android's geocoder reports its full address line as `street`.
      addressLine: clean(mark?.street),
      subLocality: clean(mark?.subLocality),
      locality: clean(mark?.locality),
      subAdministrativeArea: clean(mark?.subAdministrativeArea),
      administrativeArea: clean(mark?.administrativeArea),
      postalCode: clean(mark?.postalCode),
      country: clean(mark?.country),
      countryCode: clean(mark?.isoCountryCode),
    );
  }

  static Future<List<Placemark>> _platformGeocoder(double lat, double lng) =>
      Geocoding().placemarkFromCoordinates(lat, lng);

  /// Great-circle distance in meters.
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earth = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earth * math.asin(math.sqrt(a));
  }
}
