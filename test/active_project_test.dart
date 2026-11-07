import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/camera/controllers/capture_controller.dart';
import 'package:gps_camera/features/camera/models/capture_assignment.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/projects/controllers/active_project_controller.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/services/active_project_store.dart';

import 'helpers/db_fixtures.dart';
import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DbFixture db;
  late ActiveProjectStore store;
  late Project site;

  setUpAll(() async {
    await mockPathProvider();
    await GetStorage.init('active_project_test');
  });

  setUp(() async {
    db = DbFixture();
    final box = GetStorage('active_project_test');
    await box.erase();
    store = ActiveProjectStore(StorageService(box));
    site = await db.repo.create(name: 'Site A');
  });
  tearDown(() => db.close());

  Future<ActiveProjectController> controller() async {
    final c = ActiveProjectController(db.repo, store);
    await c.load();
    return c;
  }

  File capture(String name) => File('/data/app/GPSCamera/Photos/$name');

  test('remembers the active project across app restarts', () async {
    final first = await controller();
    await first.select(site);

    final afterRestart = await controller();
    expect(afterRestart.active.value?.id, site.id);
  });

  test('forgets an archived or deleted project', () async {
    await (await controller()).select(site);
    await db.repo.archive(site.id);
    expect((await controller()).active.value, isNull);
    expect(store.load(), isNull);

    final other = await db.repo.create(name: 'B');
    await (await controller()).select(other);
    await db.repo.delete(other.id);
    expect((await controller()).active.value, isNull);
  });

  test(
    'a capture is added to the active project by its original path',
    () async {
      final c = await controller();
      await c.select(site);

      final result = await c.assignCapture(capture('IMG_9.jpg'));

      expect(result, isA<AssignedToProject>());
      expect((result as AssignedToProject).projectName, 'Site A');
      expect((await db.repo.assignments()).keys, ['Photos/IMG_9.jpg']);
    },
  );

  test('without an active project nothing is assigned', () async {
    final c = await controller();
    expect(await c.assignCapture(capture('IMG_9.jpg')), isA<NotAssigned>());
    expect(await db.repo.assignments(), isEmpty);
  });

  test('changing the project never moves earlier photos', () async {
    final c = await controller();
    await c.select(site);
    await c.assignCapture(capture('IMG_1.jpg'));
    final other = await db.repo.create(name: 'B');
    await c.select(other);
    await c.assignCapture(capture('IMG_2.jpg'));
    await c.select(null);
    await c.assignCapture(capture('IMG_3.jpg'));

    final assignments = await db.repo.assignments();
    expect(assignments['Photos/IMG_1.jpg']!.name, 'Site A');
    expect(assignments['Photos/IMG_2.jpg']!.name, 'B');
    expect(assignments.containsKey('Photos/IMG_3.jpg'), isFalse);
  });

  test('database failures are reported, never thrown', () async {
    final c = await controller();
    await c.select(site);
    await db.close();

    final result = await c.assignCapture(capture('IMG_9.jpg'));
    expect(result, isA<AssignmentFailed>());
  });

  test('a project archived after selection stops being used', () async {
    final c = await controller();
    await c.select(site);
    await db.repo.archive(site.id);

    expect(
      await c.assignCapture(capture('IMG_9.jpg')),
      isA<AssignmentFailed>(),
    );
    expect(c.active.value, isNull);
  });

  group('capture feedback', () {
    final saved = SavedCapture(
      photo: File('/x/IMG_1.jpg'),
      metadataFile: File('/x/IMG_1.json'),
      metadata: PhotoMetadata.create(
        imageFileName: 'IMG_1.jpg',
        capturedAt: DateTime.utc(2026),
        location: const LocationSnapshot.unavailable(
          LocationUnavailableReason.noFixYet,
        ),
      ),
    );

    test('names the project the photo went into', () {
      expect(
        CaptureController.captureFeedbackMessage(
          saved,
          const AssignedToProject('Site A'),
        ),
        'Photo saved · no location · Site A',
      );
    });

    test('says plainly when the project could not be set', () {
      expect(
        CaptureController.captureFeedbackMessage(
          saved,
          const AssignmentFailed('Site A'),
        ),
        'Photo saved · no location, but it could not be added to Site A',
      );
      expect(
        CaptureController.captureFeedbackMessage(saved),
        'Photo saved · no location',
      );
    });
  });
}
