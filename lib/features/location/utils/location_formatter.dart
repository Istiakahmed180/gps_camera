import 'package:gps_camera/core/settings/display_format.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';

/// Display formatting only. Stored values are never rounded.
abstract final class LocationFormatter {
  static String latitude(double value) =>
      '${value.abs().toStringAsFixed(6)}° ${value >= 0 ? 'N' : 'S'}';

  static String longitude(double value) =>
      '${value.abs().toStringAsFixed(6)}° ${value >= 0 ? 'E' : 'W'}';

  /// One decimal for small values (under 10 m or 30 ft) so they are not
  /// rounded to look better.
  static String accuracy(double meters, {DisplayFormat? format}) {
    final f = format ?? DisplayFormat.current;
    final value = f.convert(meters);
    final small = f.units == UnitSystem.metric ? value < 10 : value < 30;
    final text = small ? value.toStringAsFixed(1) : '${value.round()}';
    return '±$text ${f.units.symbol}';
  }

  static String altitude(
    double meters,
    AltitudeReference? reference, {
    DisplayFormat? format,
  }) {
    final f = format ?? DisplayFormat.current;
    final suffix = switch (reference) {
      AltitudeReference.meanSeaLevel => ' MSL',
      AltitudeReference.wgs84Ellipsoid => ' WGS84',
      null => '',
    };
    return 'Alt ${f.convert(meters).round()} ${f.units.symbol}$suffix';
  }
}
