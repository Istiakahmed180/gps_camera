import 'package:gps_camera/features/location/models/location_fix.dart';

/// Display formatting only. Stored values are never rounded.
abstract final class LocationFormatter {
  static String latitude(double value) =>
      '${value.abs().toStringAsFixed(6)}° ${value >= 0 ? 'N' : 'S'}';

  static String longitude(double value) =>
      '${value.abs().toStringAsFixed(6)}° ${value >= 0 ? 'E' : 'W'}';

  /// One decimal under 10 m so small values are not rounded to look better.
  static String accuracy(double meters) =>
      meters < 10 ? '±${meters.toStringAsFixed(1)} m' : '±${meters.round()} m';

  static String altitude(double meters, AltitudeReference? reference) {
    final suffix = switch (reference) {
      AltitudeReference.meanSeaLevel => ' MSL',
      AltitudeReference.wgs84Ellipsoid => ' WGS84',
      null => '',
    };
    return 'Alt ${meters.round()} m$suffix';
  }
}
