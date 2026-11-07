/// Open Location Code ("Plus Code") encoding, computed offline from
/// coordinates. Same algorithm Google Maps uses; reference:
/// https://github.com/google/open-location-code
abstract final class PlusCode {
  static const String _alphabet = '23456789CFGHJMPQRVWX';
  static const int _latMultiplier = 8000 * 3125;
  static const int _lngMultiplier = 8000 * 1024;
  static const int _pairDigits = 10;
  static const int _gridDigits = 5;

  /// Full code, e.g. `7MMGWC62+8CJ`. [length] is 10 (≈14 m) or 11 (≈3 m).
  static String encode(double latitude, double longitude, {int length = 11}) {
    assert(length == 10 || length == 11, 'only 10 or 11 digits supported');

    var lat = _round(latitude * _latMultiplier) + 90 * _latMultiplier;
    lat = lat.clamp(0, 180 * _latMultiplier - 1);
    var lng = _round(longitude * _lngMultiplier) + 180 * _lngMultiplier;
    lng %= 360 * _lngMultiplier;

    final code = StringBuffer();
    final digits = <String>[];
    if (length > _pairDigits) {
      for (var i = 0; i < _gridDigits; i++) {
        digits.add(_alphabet[(lat % 5) * 4 + (lng % 4)]);
        lat ~/= 5;
        lng ~/= 4;
      }
    } else {
      lat ~/= 3125;
      lng ~/= 1024;
    }
    final pairs = <String>[];
    for (var i = 0; i < _pairDigits ~/ 2; i++) {
      pairs
        ..add(_alphabet[lng % 20])
        ..add(_alphabet[lat % 20]);
      lat ~/= 20;
      lng ~/= 20;
    }
    final all = [...pairs.reversed, ...digits.reversed].join();
    code
      ..write(all.substring(0, 8))
      ..write('+')
      ..write(all.substring(8, length));
    return code.toString();
  }

  /// Floors after removing floating-point noise, as the reference does.
  static int _round(double value) => ((value * 1e6).round() / 1e6).floor();
}
