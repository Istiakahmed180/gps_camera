import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/features/gallery/controllers/photo_details_controller.dart';
import 'package:gps_camera/features/gallery/models/gallery_filter.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/projects/controllers/project_details_controller.dart';
import 'package:gps_camera/features/projects/controllers/project_photo_picker_controller.dart';
import 'package:gps_camera/features/projects/models/project.dart';

import 'helpers/db_fixtures.dart';
import 'helpers/gallery_fixtures.dart';
import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GalleryFixture files;
  late DbFixture db;
  late GalleryService service;
  late GalleryController gallery;
  late Project site;

  setUp(() async {
    files = GalleryFixture(await mockPathProvider());
    files
      ..original('IMG_1')
      ..watermarked('IMG_1', 'IMG_1_wm')
      ..original('IMG_2');
    db = DbFixture();
    service = GalleryService(PhotoStorageService());
    site = await db.repo.create(name: 'Site');
    gallery = Get.put(GalleryController(service, db.repo));
    await gallery.reload();
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  GalleryPhoto photo(String id) => gallery.index.value.byId(id)!;

  PhotoDetailsController details(GalleryPhoto p) => PhotoDetailsController(
    photo: p,
    library: gallery,
    service: service,
    share: ShareService(share: (_) => throw UnimplementedError()),
    projects: db.repo,
  );

  List<String> names(Iterable<GalleryPhoto> photos) =>
      photos.map((p) => p.fileName).toList()..sort();

  List<String> fileNames(Directory dir) =>
      dir.listSync().map((f) => f.uri.pathSegments.last).toList()..sort();

  group('gallery', () {
    test('watermarked copies show their original project', () async {
      await db.repo.assign('Photos/IMG_1.jpg', site.id);
      await gallery.reloadAssignments();

      expect(gallery.projectOf(photo('original/IMG_1.jpg'))?.name, 'Site');
      expect(
        gallery.projectOf(photo('watermarked/IMG_1_wm.jpg'))?.name,
        'Site',
      );
      expect(gallery.projectOf(photo('original/IMG_2.jpg')), isNull);
    });

    test('filters by project together with the kind filter', () async {
      await db.repo.assign('Photos/IMG_1.jpg', site.id);
      await gallery.reloadAssignments();

      gallery.setProjectFilter(ProjectFilter.project(site.id));
      expect(names(gallery.visible), ['IMG_1.jpg', 'IMG_1_wm.jpg']);

      gallery.setFilter(GalleryFilter.watermarked);
      expect(names(gallery.visible), ['IMG_1_wm.jpg']);

      gallery
        ..setFilter(GalleryFilter.all)
        ..setProjectFilter(ProjectFilter.none);
      expect(names(gallery.visible), ['IMG_2.jpg']);
    });

    test('repairs rows for files removed outside the app', () async {
      await db.repo.assign('Photos/IMG_2.jpg', site.id);
      File('${files.photos.path}/IMG_2.jpg').deleteSync();

      await gallery.reload();

      expect(await db.repo.assignments(), isEmpty);
      expect(await db.repo.find(site.id), isNotNull);
    });

    test('an incomplete scan never removes assignments', () async {
      await db.repo.assign('Photos/IMG_1.jpg', site.id);
      final broken = GalleryController(
        FakeGalleryService(GalleryIndex(photos: const [], complete: false)),
        db.repo,
      );
      await broken.reload();

      expect((await db.repo.assignments()).keys, ['Photos/IMG_1.jpg']);
    });
  });

  group('photo details', () {
    test('a watermarked copy assigns its original, never itself', () async {
      final error = await details(photo('watermarked/IMG_1_wm.jpg'))
          .setProject(site);

      expect(error, isNull);
      expect((await db.repo.assignments()).keys, ['Photos/IMG_1.jpg']);
      expect(gallery.projectOf(photo('original/IMG_1.jpg'))?.id, site.id);
    });

    test('a copy whose original is gone cannot change project', () async {
      files.watermarked('IMG_gone', 'IMG_gone_wm');
      await gallery.reload();
      final copy = details(photo('watermarked/IMG_gone_wm.jpg'));

      expect(copy.canChangeProject, isFalse);
      expect(await copy.setProject(site), isNotNull);
      expect(await db.repo.assignments(), isEmpty);
    });

    test('removing from a project keeps the photo and the project', () async {
      await db.repo.assign('Photos/IMG_1.jpg', site.id);
      await gallery.reloadAssignments();

      await details(photo('original/IMG_1.jpg')).setProject(null);

      expect(await db.repo.assignments(), isEmpty);
      expect(File('${files.photos.path}/IMG_1.jpg').existsSync(), isTrue);
      expect(await db.repo.find(site.id), isNotNull);
    });

    test('deleting a copy keeps the original in its project', () async {
      await db.repo.assign('Photos/IMG_1.jpg', site.id);
      await gallery.reloadAssignments();
      final copy = details(photo('watermarked/IMG_1_wm.jpg'));

      await copy.delete(copy.planDelete(), includeRelated: false);

      expect((await db.repo.assignments()).keys, ['Photos/IMG_1.jpg']);
    });

    test(
      'deleting an original removes its assignment, not the project',
      () async {
        await db.repo.assign('Photos/IMG_1.jpg', site.id);
        await db.repo.update(
          site.id,
          name: 'Site',
          description: '',
          coverPhotoRef: 'Photos/IMG_1.jpg',
        );
        await gallery.reloadAssignments();
        final original = details(photo('original/IMG_1.jpg'));

        final result = await original.delete(
          original.planDelete(),
          includeRelated: true,
        );

        expect(result.isComplete, isTrue);
        expect(await db.repo.assignments(), isEmpty);
        final kept = (await db.repo.find(site.id))!;
        expect(kept.coverPhotoRef, isNull);
        expect((await db.repo.summaries(archived: false)).single.photoCount, 0);
      },
    );
  });

  group('project details', () {
    late ProjectDetailsController project;

    setUp(() async {
      await db.repo.assign('Photos/IMG_1.jpg', site.id);
      project = ProjectDetailsController(
        projectId: site.id,
        repo: db.repo,
        gallery: service,
      );
      await project.reload();
    });

    test('shows its originals and their watermarked copies', () {
      expect(project.originalCount, 1);
      expect(project.watermarkedCount, 1);
      expect(names(project.visible), ['IMG_1.jpg', 'IMG_1_wm.jpg']);
      expect(project.missingCount, 0);
    });

    test('archive and restore', () async {
      expect(await project.setArchived(true), isNull);
      expect(project.project.value!.isArchived, isTrue);
      expect(await project.setArchived(false), isNull);
      expect(project.project.value!.isArchived, isFalse);
    });

    test('deleting the project deletes no photo files', () async {
      final before = [...fileNames(files.photos), ...fileNames(files.outputs)];

      expect(await project.delete(), isNull);

      expect(await db.repo.find(site.id), isNull);
      expect(await db.repo.assignments(), isEmpty);
      expect([...fileNames(files.photos), ...fileNames(files.outputs)], before);
      await gallery.reload();
      expect(gallery.index.value.photos, hasLength(3));
    });
  });

  group('add photos', () {
    test('offers originals only and flags photos that will move', () async {
      final other = await db.repo.create(name: 'Other');
      await db.repo.assign('Photos/IMG_2.jpg', other.id);
      await db.repo.assign('Photos/IMG_1.jpg', site.id);
      final picker = ProjectPhotoPickerController(
        projectId: site.id,
        repo: db.repo,
        gallery: service,
      );
      await picker.load();

      expect(names(picker.originals), ['IMG_1.jpg', 'IMG_2.jpg']);
      final inSite = picker.originals.firstWhere(
        (p) => p.fileName == 'IMG_1.jpg',
      );
      final inOther = picker.originals.firstWhere(
        (p) => p.fileName == 'IMG_2.jpg',
      );

      picker.toggle(inSite);
      expect(picker.selected, isEmpty, reason: 'already in this project');

      picker.toggle(inOther);
      expect(picker.movingCount, 1);
      picker.toggle(inOther);
      expect(picker.selected, isEmpty);
    });
  });
}
