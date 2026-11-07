import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/projects/controllers/project_details_controller.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';

import 'helpers/db_fixtures.dart';
import 'helpers/gallery_fixtures.dart';
import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GalleryFixture files;
  late DbFixture db;
  late GalleryService service;
  late GalleryController gallery;

  setUp(() async {
    files = GalleryFixture(await mockPathProvider());
    files
      ..original('IMG_1', capturedAt: DateTime.utc(2026, 1, 2))
      ..watermarked('IMG_1', 'IMG_1_wm')
      ..original('IMG_2', capturedAt: DateTime.utc(2026, 1, 3));
    db = DbFixture();
    service = GalleryService(PhotoStorageService());
    gallery = Get.put(GalleryController(service, db.repo));
    await gallery.reload();
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  List<String> all() => [
    ...files.photos.listSync().map((f) => f.path),
    ...files.outputs.listSync().map((f) => f.path),
  ]..sort();

  group('selection', () {
    test('selecting and cancelling changes no files or projects', () async {
      final site = await db.repo.create(name: 'Site');
      await db.repo.assign('Photos/IMG_1.jpg', site.id);
      await gallery.reloadAssignments();
      final before = all();

      gallery
        ..startSelection(gallery.index.value.byId('original/IMG_1.jpg'))
        ..selectAllVisible();
      expect(gallery.selectedIds, hasLength(3));
      gallery.cancelSelection();

      expect(gallery.selecting.value, isFalse);
      expect(gallery.selectedIds, isEmpty);
      expect(all(), before);
      expect((await db.repo.assignments()).keys, ['Photos/IMG_1.jpg']);
    });

    test('an original and its copy make one report entry', () {
      gallery
        ..startSelection()
        ..toggleSelection(gallery.index.value.byId('original/IMG_1.jpg')!)
        ..toggleSelection(gallery.index.value.byId('watermarked/IMG_1_wm.jpg')!)
        ..toggleSelection(gallery.index.value.byId('original/IMG_2.jpg')!);

      final job = gallery.selectionReport(now: DateTime(2026, 11, 7))!;

      expect(gallery.selectedIds, hasLength(3));
      expect(job.type, ReportType.selection);
      expect(job.entries.map((e) => e.fileName), ['IMG_1.jpg', 'IMG_2.jpg']);
      expect(job.entries.first.images, hasLength(2));
    });

    test('an empty selection makes no report', () {
      gallery.startSelection();
      expect(gallery.selectionReport(), isNull);
    });

    test('photos deleted meanwhile drop out of the selection', () async {
      gallery.startSelection(gallery.index.value.byId('original/IMG_2.jpg'));
      File('${files.photos.path}/IMG_2.jpg').deleteSync();
      await gallery.reload();

      expect(gallery.selectedIds, isEmpty);
    });
  });

  group('project report', () {
    test('includes the project originals with their copies', () async {
      final site = await db.repo.create(name: 'Site', description: 'Roof');
      await db.repo.assign('Photos/IMG_1.jpg', site.id);
      final details = ProjectDetailsController(
        projectId: site.id,
        repo: db.repo,
        gallery: service,
      );
      await details.reload();

      final job = details.reportJob(now: DateTime(2026, 11, 7))!;
      expect(job.projectName, 'Site');
      expect(job.projectDescription, 'Roof');
      expect(job.entries.single.fileName, 'IMG_1.jpg');
      expect(job.watermarkedVersionCount, 1);
    });

    test('an empty project makes no report', () async {
      final empty = await db.repo.create(name: 'Empty');
      final details = ProjectDetailsController(
        projectId: empty.id,
        repo: db.repo,
        gallery: service,
      );
      await details.reload();
      expect(details.reportJob(), isNull);
    });
  });
}
