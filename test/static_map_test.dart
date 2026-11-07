import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/features/location/controllers/live_map_controller.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/location/services/static_map_service.dart';
import 'package:image/image.dart' as img;

import 'helpers/test_env.dart';

/// A real 8×8 PNG.
final Uint8List _png = img.encodePng(
  img.Image(width: 8, height: 8)..clear(img.ColorRgb8(200, 220, 240)),
);

/// Returns canned results instead of calling the network.
class _FakeMaps extends StaticMapService {
  _FakeMaps(this.result) : super('test-key');

  Uint8List? result;
  final List<(double, double)> calls = [];

  @override
  Future<Uint8List?> fetch(double latitude, double longitude) async {
    calls.add((latitude, longitude));
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StaticMapService', () {
    test('builds a Geoapify static map URL centred on the point', () {
      final url = StaticMapService('k123').urlFor(23.9109, 90.401);
      expect(url.host, 'maps.geoapify.com');
      expect(url.path, '/v1/staticmap');
      expect(url.queryParameters['center'], 'lonlat:90.401,23.9109');
      expect(
        url.queryParameters['marker'],
        startsWith('lonlat:90.401,23.9109;'),
      );
      expect(url.queryParameters['apiKey'], 'k123');
      expect(url.queryParameters['format'], 'png');
    });

    test('returns null instead of throwing when offline', () async {
      final service = StaticMapService(
        'k',
        timeout: const Duration(milliseconds: 200),
      );
      // Point at an unroutable local port by overriding the URL host.
      final offline = _Unreachable('k');
      expect(await offline.fetch(1, 2), isNull);
      expect(service.timeout, const Duration(milliseconds: 200));
    });
  });

  group('LiveMapController', () {
    late FakeLocationService location;
    late LocationController locations;
    late _FakeMaps maps;
    var now = DateTime.utc(2026, 11, 7, 6);

    Future<LiveMapController> build({String? key = 'k'}) async {
      const channel = MethodChannel('test/native');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => key);
      final c = LiveMapController(
        locations,
        channel: channel,
        serviceFor: (_) => maps,
      )..onInit();
      await pumpEventQueue();
      return c;
    }

    Future<void> fixAt(double lat, double lng) async {
      now = now.add(const Duration(seconds: 1));
      location.emit(testFix(latitude: lat, longitude: lng, timestamp: now));
      await pumpEventQueue();
    }

    setUp(() async {
      location = FakeLocationService();
      locations = LocationController(
        location,
        FakePermissionService(),
        clock: () => now,
      )..onInit();
      await locations.start();
      maps = _FakeMaps(_png);
    });

    tearDown(() => locations.onClose());

    test(
      'without a key the map is unavailable and nothing is fetched',
      () async {
        final c = await build(key: null);
        await fixAt(23.91, 90.40);
        expect(c.available.value, isFalse);
        expect(maps.calls, isEmpty);
        expect(await c.snapshot(), isNull);
        c.onClose();
      },
    );

    test('fetches once per spot and reuses it for captures nearby', () async {
      final c = await build();
      await fixAt(23.910913, 90.401004);
      await fixAt(23.91095, 90.40102); // ~4 m
      expect(maps.calls, hasLength(1));
      expect(await c.snapshot(), _png);
      expect(c.image.value, isNotNull);

      await fixAt(23.9115, 90.4012); // ~70 m
      expect(maps.calls, hasLength(2));
      c.onClose();
    });

    test('never returns a map of another place', () async {
      maps.result = _png;
      final c = await build();
      await fixAt(23.910913, 90.401004);
      maps.result = null; // the next fetch fails (offline)
      await fixAt(23.95, 90.45); // far away
      expect(await c.snapshot(), isNull);
      c.onClose();
    });
  });
}

class _Unreachable extends StaticMapService {
  _Unreachable(super.key) : super(timeout: const Duration(milliseconds: 300));

  @override
  Uri urlFor(double latitude, double longitude) =>
      Uri.parse('http://127.0.0.1:9/staticmap');
}
