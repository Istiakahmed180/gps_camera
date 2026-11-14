import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/features/home/controllers/current_place_controller.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/services/location_service.dart';
import 'package:gps_camera/features/location/services/place_service.dart';

import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

class _Location extends FakeLocationService {
  _Location({super.permission, super.serviceEnabled});

  LocationFix? last;
  LocationFix? current;
  int fixCalls = 0;

  @override
  Future<LocationFix?> lastKnownFix() async => last;

  @override
  Future<LocationFix> currentFix({
    Duration timeLimit = const Duration(seconds: 20),
  }) async {
    fixCalls++;
    final fix = current;
    if (fix == null) {
      throw const LocationException(LocationErrorKind.unavailable);
    }
    return fix;
  }
}

PlaceService _places({List<String>? calls}) => PlaceService(
  geocoder: (lat, lng) async {
    calls?.add('$lat,$lng');
    return [
      const Placemark(
        street: 'Station Road, Tongi',
        locality: 'Tongi',
        administrativeArea: 'Dhaka Division',
        country: 'Bangladesh',
      ),
    ];
  },
);

void main() {
  test('shows the current place and its address', () async {
    final location = _Location()..current = fixtureFix();
    final here = CurrentPlaceController(location, _places());
    await here.locate();
    expect(here.status.value, CurrentPlaceStatus.found);
    expect(here.fix.value!.latitude, 23.910908);
    expect(here.place.value!.title, 'Tongi, Dhaka Division, Bangladesh');
    expect(here.place.value!.addressLine, 'Station Road, Tongi');
  });

  test('the last known fix shows while GPS has none', () async {
    final location = _Location()..last = fixtureFix(accuracy: 30);
    final here = CurrentPlaceController(location, _places());
    await here.locate();
    expect(here.status.value, CurrentPlaceStatus.found);
    expect(here.fix.value!.accuracy, 30);
  });

  test('says why there is no location', () async {
    for (final (location, expected) in [
      (
        _Location(permission: PermissionAccess.denied),
        CurrentPlaceStatus.noPermission,
      ),
      (
        _Location(permission: PermissionAccess.blocked),
        CurrentPlaceStatus.blocked,
      ),
      (_Location(serviceEnabled: false), CurrentPlaceStatus.off),
      (_Location(), CurrentPlaceStatus.unavailable),
    ]) {
      final here = CurrentPlaceController(location, _places());
      await here.locate();
      expect(here.status.value, expected);
      expect(here.fix.value, isNull);
    }
  });

  test('asking for access then shows the place', () async {
    final location = _Location(permission: PermissionAccess.denied)
      ..current = fixtureFix();
    location.requestResult = PermissionAccess.granted;
    final here = CurrentPlaceController(location, _places());
    await here.locate();
    expect(here.status.value, CurrentPlaceStatus.noPermission);

    await here.fixAccess();
    expect(location.requestCount, 1);
    expect(here.status.value, CurrentPlaceStatus.found);
  });

  test('the address is not looked up again without moving', () async {
    final calls = <String>[];
    final location = _Location()..current = fixtureFix();
    final here = CurrentPlaceController(location, _places(calls: calls));
    await here.locate();
    await here.locate();
    expect(location.fixCalls, 2);
    expect(calls, hasLength(1));
  });

  test('lookups at the same time share one', () async {
    final location = _Location()..current = fixtureFix();
    final here = CurrentPlaceController(location, _places());
    await Future.wait([here.locate(), here.locate(), here.locate()]);
    expect(location.fixCalls, 1);
  });

  test('looks up only while resumed', () async {
    final location = _Location()..current = fixtureFix();
    final here = CurrentPlaceController(
      location,
      _places(),
      refreshEvery: const Duration(milliseconds: 10),
    );
    here
      ..resume()
      ..pause();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final before = location.fixCalls;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(location.fixCalls, before);

    here.resume();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(location.fixCalls, greaterThan(before + 1));
    here.onClose();
  });
}
