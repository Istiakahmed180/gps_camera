import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/models/location_status.dart';
import 'package:gps_camera/features/location/services/location_service.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLocationService service;
  late LocationController controller;
  var now = DateTime.utc(2026, 11, 7, 10);

  LocationController build({
    Duration firstFixTimeout = const Duration(seconds: 30),
  }) {
    controller = LocationController(
      service,
      FakePermissionService(),
      firstFixTimeout: firstFixTimeout,
      clock: () => now,
    )..onInit();
    return controller;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() => now = DateTime.utc(2026, 11, 7, 10));
  tearDown(() => controller.onClose());

  group('permission states', () {
    test('asks once when undecided and reports denied', () async {
      service = FakeLocationService(permission: PermissionAccess.denied);
      await build().start();

      expect(service.requestCount, 1);
      expect(controller.status.value, LocationStatus.permissionDenied);
      expect(service.listenCount, 0);
    });

    test('permanently denied does not prompt', () async {
      service = FakeLocationService(permission: PermissionAccess.blocked);
      await build().start();

      expect(service.requestCount, 0);
      expect(controller.status.value, LocationStatus.permissionBlocked);
    });

    test('stays blocked when Android later reports plain denied', () async {
      service = FakeLocationService(permission: PermissionAccess.blocked);
      await build().start();

      service.permission = PermissionAccess.denied;
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();

      expect(controller.status.value, LocationStatus.permissionBlocked);
    });

    test('granting from the prompt starts tracking', () async {
      service = FakeLocationService(
        permission: PermissionAccess.denied,
        requestResult: PermissionAccess.granted,
      );
      await build().start();

      expect(controller.status.value, LocationStatus.acquiring);
      expect(service.activeSubscriptions, 1);
    });

    test('revoked while running stops updates and reports denied', () async {
      service = FakeLocationService();
      await build().start();
      service.emit(testFix(timestamp: now));
      await settle();

      service.permission = PermissionAccess.denied;
      service.emitError(
        const LocationException(LocationErrorKind.permissionDenied),
      );
      await settle();

      expect(service.activeSubscriptions, 0);
      expect(controller.status.value, LocationStatus.permissionDenied);
    });
  });

  group('location services', () {
    test('disabled services are reported and nothing is requested', () async {
      service = FakeLocationService(serviceEnabled: false);
      await build().start();

      expect(controller.status.value, LocationStatus.serviceDisabled);
      expect(service.listenCount, 0);
      expect(
        controller.snapshotAt(now).reason,
        LocationUnavailableReason.locationServicesDisabled,
      );
    });

    test('turning services on resumes tracking', () async {
      service = FakeLocationService(serviceEnabled: false);
      await build().start();

      service.serviceEnabled = true;
      service.serviceChanges.add(true);
      await settle();
      await settle();

      expect(controller.status.value, LocationStatus.acquiring);
      expect(service.activeSubscriptions, 1);
    });

    test('turning services off mid-stream stops tracking', () async {
      service = FakeLocationService();
      await build().start();
      service.emitError(
        const LocationException(LocationErrorKind.serviceDisabled),
      );
      await settle();

      expect(controller.status.value, LocationStatus.serviceDisabled);
      expect(service.activeSubscriptions, 0);
    });
  });

  group('fixes', () {
    test('valid fix makes GPS ready and the snapshot current', () async {
      service = FakeLocationService();
      await build().start();
      final fix = testFix(timestamp: now);
      service.emit(fix);
      await settle();

      expect(controller.status.value, LocationStatus.ready);
      expect(controller.accuracyLevel, GpsAccuracyLevel.good);

      final snapshot = controller.snapshotAt(
        now.add(const Duration(seconds: 3)),
      );
      expect(snapshot.status, LocationRecordStatus.current);
      expect(snapshot.fix, fix);
      expect(snapshot.fixAge, const Duration(seconds: 3));
    });

    test('poor accuracy keeps the real value and is marked poor', () async {
      service = FakeLocationService();
      await build().start();
      service.emit(testFix(accuracy: 48.7, timestamp: now));
      await settle();

      final snapshot = controller.snapshotAt(now);
      expect(snapshot.status, LocationRecordStatus.current);
      expect(snapshot.fix!.accuracy, 48.7);
      expect(snapshot.accuracyLevel, GpsAccuracyLevel.poor);
    });

    test('an old fix is recorded as stale, never current', () async {
      service = FakeLocationService();
      await build().start();
      final old = testFix(timestamp: now.subtract(const Duration(minutes: 2)));
      service.emit(old);
      await settle();

      expect(controller.isStale.value, isTrue);
      final snapshot = controller.snapshotAt(now);
      expect(snapshot.status, LocationRecordStatus.stale);
      expect(snapshot.fixAge, const Duration(minutes: 2));
    });

    test('a fix becomes stale once tracking stops', () async {
      service = FakeLocationService();
      await build().start();
      service.emit(testFix(timestamp: now));
      await settle();

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(controller.snapshotAt(now).status, LocationRecordStatus.stale);
    });

    test('a brief coarse fallback does not replace a good fix', () async {
      service = FakeLocationService();
      await build().start();
      final good = testFix(
        accuracy: 26,
        timestamp: now.subtract(const Duration(seconds: 4)),
      );
      service.emit(good);
      await settle();
      service.emit(
        testFix(
          latitude: 23.9,
          accuracy: 790,
          timestamp: now.subtract(const Duration(seconds: 1)),
        ),
      );
      await settle();

      expect(controller.fix.value, good);
      final snapshot = controller.snapshotAt(now);
      expect(snapshot.fix, good);
      expect(snapshot.fix!.accuracy, 26);
      expect(snapshot.fixAge, const Duration(seconds: 4));
    });

    test('a slightly better but older fix loses to the latest', () async {
      service = FakeLocationService();
      await build().start();
      service.emit(
        testFix(
          accuracy: 4,
          timestamp: now.subtract(const Duration(seconds: 8)),
        ),
      );
      await settle();
      final latest = testFix(accuracy: 12, timestamp: now);
      service.emit(latest);
      await settle();

      expect(controller.snapshotAt(now).fix, latest);
    });

    test('fixes outside the window are never preferred', () async {
      service = FakeLocationService();
      await build().start();
      service.emit(
        testFix(
          accuracy: 3,
          timestamp: now.subtract(const Duration(seconds: 20)),
        ),
      );
      await settle();
      final latest = testFix(accuracy: 60, timestamp: now);
      service.emit(latest);
      await settle();

      final snapshot = controller.snapshotAt(now);
      expect(snapshot.fix, latest);
      expect(snapshot.accuracyLevel, GpsAccuracyLevel.poor);
    });

    test('resuming with an old fix waits for a fresh one', () async {
      service = FakeLocationService();
      await build().start();
      service.emit(testFix(timestamp: now));
      await settle();

      controller.suspend();
      now = now.add(const Duration(minutes: 2));
      await controller.resume();

      expect(controller.status.value, LocationStatus.acquiring);
      expect(controller.isStale.value, isTrue);
      expect(controller.snapshotAt(now).status, LocationRecordStatus.stale);

      service.emit(testFix(timestamp: now));
      await settle();
      expect(controller.status.value, LocationStatus.ready);
      expect(controller.snapshotAt(now).status, LocationRecordStatus.current);
    });

    test('no fix in time reports GPS unavailable', () async {
      service = FakeLocationService();
      await build(firstFixTimeout: const Duration(milliseconds: 20)).start();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller.status.value, LocationStatus.unavailable);
      expect(
        controller.snapshotAt(now).reason,
        LocationUnavailableReason.gpsUnavailable,
      );
    });

    test('before any fix the snapshot is unavailable', () async {
      service = FakeLocationService();
      await build().start();

      final snapshot = controller.snapshotAt(now);
      expect(snapshot.status, LocationRecordStatus.unavailable);
      expect(snapshot.reason, LocationUnavailableReason.noFixYet);
      expect(snapshot.fix, isNull);
    });
  });

  group('lifecycle', () {
    test('never opens a second subscription', () async {
      service = FakeLocationService();
      build();
      await controller.start();
      await controller.start();
      await controller.retry();

      expect(service.listenCount, 1);
      expect(service.activeSubscriptions, 1);
    });

    test('pauses in background and resumes once', () async {
      service = FakeLocationService();
      await build().start();

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(service.activeSubscriptions, 0);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await settle();
      expect(service.activeSubscriptions, 1);
    });

    test('closing the screen cancels updates', () async {
      service = FakeLocationService();
      await build().start();
      controller.onClose();

      expect(service.activeSubscriptions, 0);
    });
  });
}
