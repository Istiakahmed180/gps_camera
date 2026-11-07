import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/features/location/utils/plus_code.dart';

void main() {
  test('matches the official Open Location Code test vectors', () {
    // From google/open-location-code test_data/encoding.csv
    expect(PlusCode.encode(20.3700625, 2.7821875, length: 10), '7FG49QCJ+2V');
    expect(PlusCode.encode(20.3701125, 2.782234375), '7FG49QCJ+2VX');
    expect(PlusCode.encode(47.0000625, 8.0000625, length: 10), '8FVC2222+22');
    expect(
      PlusCode.encode(-41.2730625, 174.7859375, length: 10),
      '4VCPPQGP+Q9',
    );
  });

  test('lies in the same area as Google shows for the test site', () {
    // Google's geocoder labels the matched address "WC62+8CJ"; the exact
    // GPS fix falls in a neighbouring 14 m cell of the same area.
    final code = PlusCode.encode(23.910913, 90.401004);
    expect(code, startsWith('7MMGWC62+'));
    expect(code, hasLength(12));
  });

  test('handles the poles and the antimeridian', () {
    expect(PlusCode.encode(90, 180), hasLength(12));
    expect(PlusCode.encode(-90, -180), startsWith('2222'));
  });
}
