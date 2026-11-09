import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/backup/services/backup_service.dart';
import 'package:gps_camera/features/camera/services/capture_enricher.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/features/export/models/gallery_save_mode.dart';
import 'package:gps_camera/features/export/services/gallery_export_service.dart';
import 'package:gps_camera/features/export/services/phone_gallery.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';

import 'helpers/db_fixtures.dart';
import 'helpers/gallery_fixtures.dart';
import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

class FakePhoneGallery extends PhoneGallery {
  FakePhoneGallery({this.available = true});

  bool available;
  PhoneGallerySave? forced;
  final List<String> saved = [];
  final Map<String, DateTime?> takenAt = {};

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<PhoneGallerySave> save(File file, {DateTime? takenAt}) async {
    if (!available) return PhoneGallerySave.unsupported;
    if (forced != null) return forced!;
    final name = file.uri.pathSegments.last;
    if (saved.contains(name)) return PhoneGallerySave.exists;
    saved.add(name);
    this.takenAt[name] = takenAt;
    return PhoneGallerySave.saved;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService settings;

  setUpAll(() async {
    await mockPathProvider();
    await GetStorage.init('phase9_test');
  });

  setUp(() async {
    final box = GetStorage('phase9_test');
    await box.erase();
    settings = StorageService(box);
  });

  tearDown(Get.reset);

  group('gallery save mode', () {
    test('defaults to watermarked and persists changes', () async {
      final export = GalleryExportService(settings, FakePhoneGallery());
      expect(export.mode.value, GallerySaveMode.watermarked);

      await export.setMode(GallerySaveMode.both);
      expect(settings.read<String>(StorageKeys.gallerySaveMode), 'both');
      expect(
        GalleryExportService(settings, FakePhoneGallery()).mode.value,
        GallerySaveMode.both,
      );
      expect(GallerySaveMode.parse('nonsense'), GallerySaveMode.watermarked);
    });

    test('exportCapture copies the files each mode asks for', () async {
      final original = File('/x/Photos/IMG_1.jpg');
      final copy = File('/x/Watermarked/IMG_1_wm.jpg');

      Future<List<String>> run(GallerySaveMode mode, {File? wm}) async {
        final gallery = FakePhoneGallery();
        final export = GalleryExportService(settings, gallery);
        await export.setMode(mode);
        expect(
          await export.exportCapture(original: original, watermarked: wm),
          isTrue,
        );
        return gallery.saved;
      }

      expect(await run(GallerySaveMode.off, wm: copy), isEmpty);
      expect(await run(GallerySaveMode.watermarked, wm: copy), [
        'IMG_1_wm.jpg',
      ]);
      expect(await run(GallerySaveMode.watermarked), ['IMG_1.jpg']);
      expect(await run(GallerySaveMode.original, wm: copy), ['IMG_1.jpg']);
      expect(await run(GallerySaveMode.both, wm: copy), [
        'IMG_1.jpg',
        'IMG_1_wm.jpg',
      ]);
      expect(await run(GallerySaveMode.both), ['IMG_1.jpg']);
    });

    test('reports a failed copy but not an unsupported phone', () async {
      final gallery = FakePhoneGallery()..forced = PhoneGallerySave.failed;
      final export = GalleryExportService(settings, gallery);
      expect(
        await export.exportCapture(original: File('/x/Photos/IMG_1.jpg')),
        isFalse,
      );
      gallery.forced = PhoneGallerySave.unsupported;
      expect(
        await export.exportCapture(original: File('/x/Photos/IMG_1.jpg')),
        isTrue,
      );
    });

    test('editor copies go to the gallery only when the mode includes '
        'watermarked photos', () async {
      final gallery = FakePhoneGallery();
      final export = GalleryExportService(settings, gallery);
      final copy = File('/x/Watermarked/IMG_1_wm_1.jpg');

      await export.setMode(GallerySaveMode.original);
      await export.exportEdited(copy);
      expect(gallery.saved, isEmpty);

      await export.setMode(GallerySaveMode.watermarked);
      await export.exportEdited(copy);
      expect(gallery.saved, ['IMG_1_wm_1.jpg']);
    });

    test('exportExisting follows the mode, oldest first, and can run '
        'again without duplicates', () async {
      final files = GalleryFixture(await mockPathProvider());
      files
        ..original('IMG_A', capturedAt: DateTime.utc(2025, 12, 30))
        ..watermarked('IMG_A', 'IMG_A_wm', renderedAt: DateTime.utc(2026, 1, 2))
        ..original('IMG_B', capturedAt: DateTime.utc(2026, 1, 3))
        ..watermarked(
          'IMG_GONE',
          'IMG_GONE_wm',
          renderedAt: DateTime.utc(2026, 1, 4),
        );
      final index = await GalleryService(PhotoStorageService()).scan();

      final gallery = FakePhoneGallery();
      final export = GalleryExportService(settings, gallery);
      expect(export.plan(index).map((p) => p.fileName), [
        'IMG_A_wm.jpg',
        'IMG_B.jpg',
        'IMG_GONE_wm.jpg',
      ], reason: 'watermarked mode: copies, or the original when none');

      await export.setMode(GallerySaveMode.original);
      expect(export.plan(index).map((p) => p.fileName), [
        'IMG_A.jpg',
        'IMG_B.jpg',
      ]);

      await export.setMode(GallerySaveMode.both);
      final first = await export.exportExisting(index);
      expect(first.saved, 4);
      expect(gallery.saved, [
        'IMG_A.jpg',
        'IMG_A_wm.jpg',
        'IMG_B.jpg',
        'IMG_GONE_wm.jpg',
      ]);
      expect(gallery.takenAt['IMG_A.jpg'], DateTime.utc(2025, 12, 30));

      final again = await export.exportExisting(index);
      expect(again.saved, 0);
      expect(again.alreadyThere, 4);

      await export.setMode(GallerySaveMode.off);
      expect(export.plan(index), isEmpty);
    });

    test('a new capture is copied to the gallery after enrichment', () async {
      await mockPathProvider();
      final storage = PhotoStorageService();
      final store = WatermarkSettingsStore(settings);
      await store.saveAutoWatermark(false);
      final photos = await storage.photosDirectory();
      final photo = writeTestJpeg('${photos.path}/IMG_cap.jpg');
      final metadata = fixtureMetadata();
      final saved = SavedCapture(
        photo: photo,
        metadata: metadata,
        metadataFile: await storage.saveMetadata(photo, metadata.toJson()),
      );

      final gallery = FakePhoneGallery();
      CaptureEnricher enricher() => CaptureEnricher(
        storage: storage,
        renderer: WatermarkRenderer(storage),
        settings: store,
        placeFor: (_) async => null,
        grabMap: () async => null,
        gallery: GalleryExportService(settings, gallery),
      );

      expect(await enricher().process(saved, null), isNull);
      expect(gallery.saved, ['IMG_cap.jpg']);
      expect(gallery.takenAt['IMG_cap.jpg'], metadata.capturedAt);

      gallery
        ..saved.clear()
        ..forced = PhoneGallerySave.failed;
      final failed = await enricher().process(saved, null);
      expect(failed!.message, 'Not saved to phone gallery');
      expect(failed.isError, isTrue, reason: 'shown as an error');
    });
  });

  group('backup', () {
    late Directory root;
    late DbFixture db;
    late Directory temp;
    late Directory keep;

    setUp(() async {
      root = await mockPathProvider();
      db = DbFixture();
      temp = await Directory.systemTemp.createTemp('backup_cache');
      keep = await Directory.systemTemp.createTemp('backup_keep');
    });

    tearDown(() => db.close());

    BackupService service(DbFixture fixture) => BackupService(
      PhotoStorageService(),
      fixture.db,
      settings,
      tempDirectory: () async => temp,
      clock: () => DateTime(2026, 11, 7, 15, 4, 5),
    );

    File write(String ref, List<int> bytes) =>
        File('${root.path}/GPSCamera/$ref')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(bytes);

    /// Makes a backup of the current root and keeps a copy outside the
    /// cache, which the service clears.
    Future<File> backupNow() async {
      final s = service(db);
      final backup = await s.create();
      final copy = backup.file.copySync('${keep.path}/${backup.name}');
      await s.discard(backup.file);
      expect(backup.file.existsSync(), isFalse);
      return copy;
    }

    Archive open(File zip) => ZipDecoder().decodeBytes(zip.readAsBytesSync());

    test('contains every file, projects and settings', () async {
      final files = GalleryFixture(root);
      files
        ..original('IMG_1')
        ..watermarked('IMG_1', 'IMG_1_wm')
        ..original('IMG_2');
      write('Maps/IMG_1_map.png', [1, 2, 3]);
      write('Reports/Site report.pdf', utf8.encode('%PDF-test'));
      write('Photos/IMG_3.jpg.tmp', [9]);
      write('Watermarked/IMG_2_wm.jpg', []);
      final site = await db.repo.create(name: 'Site');
      await db.repo.assign('Photos/IMG_1.jpg', site.id);
      await settings.write(StorageKeys.autoWatermark, false);

      final s = service(db);
      final backup = await s.create();
      expect(backup.name, 'Locaproof_Backup_20261107_150405.zip');
      expect(backup.photoCount, 2);
      expect(s.isBusy.value, isFalse);

      final archive = open(backup.file);
      final names = archive.files.map((f) => f.name).toList()..sort();
      expect(names, [
        'Maps/IMG_1_map.png',
        'Photos/IMG_1.jpg',
        'Photos/IMG_1.json',
        'Photos/IMG_2.jpg',
        'Photos/IMG_2.json',
        'Reports/Site report.pdf',
        'Watermarked/IMG_1_wm.jpg',
        'Watermarked/IMG_1_wm.json',
        'backup.json',
      ], reason: 'temp files and empty reservations are left out');
      expect(
        archive.find('Photos/IMG_1.jpg')!.readBytes(),
        File('${root.path}/GPSCamera/Photos/IMG_1.jpg').readAsBytesSync(),
      );

      final manifest = jsonDecode(
        utf8.decode(archive.find('backup.json')!.readBytes()!),
      ) as Map<String, dynamic>;
      expect(manifest['format'], 'gps_camera_backup');
      expect(manifest['version'], 1);
      expect((manifest['projects'] as List).single['name'], 'Site');
      expect(
        (manifest['projectPhotos'] as List).single['originalPhotoPath'],
        'Photos/IMG_1.jpg',
      );
      expect((manifest['settings'] as Map)[StorageKeys.autoWatermark], false);
    });

    test('restores everything onto an empty phone', () async {
      GalleryFixture(root)
        ..original('IMG_1')
        ..watermarked('IMG_1', 'IMG_1_wm');
      write('Maps/IMG_1_map.png', [1, 2, 3]);
      final site = await db.repo.create(name: 'Site', description: 'North');
      await db.repo.assign('Photos/IMG_1.jpg', site.id);
      await settings.write(StorageKeys.autoWatermark, false);
      final originalBytes = File('${root.path}/GPSCamera/Photos/IMG_1.jpg')
          .readAsBytesSync();
      final zip = await backupNow();

      // A new phone: empty storage, database and settings.
      root = await mockPathProvider();
      final fresh = DbFixture();
      addTearDown(fresh.close);
      await GetStorage('phase9_test').erase();

      final summary = await service(fresh).restore(zip);
      expect(summary.addedPhotos, 1);
      expect(summary.addedFiles, 5);
      expect(summary.skippedFiles, 0);
      expect(summary.addedProjects, 1);
      expect(summary.addedAssignments, 1);
      expect(summary.restoredSettings, isTrue);

      expect(
        File('${root.path}/GPSCamera/Photos/IMG_1.jpg').readAsBytesSync(),
        originalBytes,
      );
      expect(
        File('${root.path}/GPSCamera/Maps/IMG_1_map.png').readAsBytesSync(),
        [1, 2, 3],
      );
      final project = (await fresh.repo.activeProjects()).single;
      expect(project.id, site.id);
      expect(project.description, 'North');
      expect(await fresh.repo.photoRefsOf(site.id), {'Photos/IMG_1.jpg'});
      expect(settings.read<bool>(StorageKeys.autoWatermark), isFalse);
      expect(
        Directory('${root.path}/GPSCamera/Photos')
            .listSync()
            .where((f) => f.path.endsWith('.tmp')),
        isEmpty,
      );
    });

    test('never replaces files, projects or settings already here', () async {
      GalleryFixture(root)
        ..original('IMG_1')
        ..original('IMG_2');
      final old = await db.repo.create(name: 'Site');
      await db.repo.assign('Photos/IMG_1.jpg', old.id);
      await db.repo.assign('Photos/IMG_2.jpg', old.id);
      await settings.write(StorageKeys.autoWatermark, false);
      final zip = await backupNow();

      // This phone: a different IMG_1, its own "Site" and settings.
      root = await mockPathProvider();
      final here = DbFixture();
      addTearDown(here.close);
      final mine = write('Photos/IMG_1.jpg', [7, 7, 7]);
      final local = await here.repo.create(name: 'site');
      await here.repo.assign('Photos/IMG_1.jpg', local.id);
      await settings.write(StorageKeys.autoWatermark, true);

      final summary = await service(here).restore(zip);

      expect(mine.readAsBytesSync(), [7, 7, 7]);
      expect(summary.skippedFiles, 1, reason: 'only Photos/IMG_1.jpg');
      expect(summary.addedPhotos, 1);
      expect(summary.restoredSettings, isFalse);
      expect(settings.read<bool>(StorageKeys.autoWatermark), isTrue);

      final names = (await here.repo.activeProjects()).map((p) => p.name);
      expect(names, containsAll(['site', 'Site (restored)']));
      expect(await here.repo.photoRefsOf(local.id), {'Photos/IMG_1.jpg'});
      expect(await here.repo.photoRefsOf(old.id), {'Photos/IMG_2.jpg'});

      final again = await service(here).restore(zip);
      expect(again.addedFiles, 0);
      expect(again.addedProjects, 0);
      expect(again.addedAssignments, 0);
    });

    Future<File> craft(Map<String, List<int>> entries) async {
      final archive = Archive();
      entries.forEach(
        (name, bytes) =>
            archive.add(ArchiveFile.bytes(name, Uint8List.fromList(bytes))),
      );
      final file = File('${keep.path}/crafted.zip');
      await file.writeAsBytes(ZipEncoder().encodeBytes(archive));
      return file;
    }

    List<int> manifest([int version = 1]) => utf8.encode(
      jsonEncode({'format': 'gps_camera_backup', 'version': version}),
    );

    test('rejects files that are not backups or are too new', () async {
      final s = service(db);
      await expectLater(
        s.restore(
          await craft({
            'Photos/IMG_1.jpg': [1],
          }),
        ),
        throwsA(isA<BackupException>()),
      );
      final notZip = File('${keep.path}/x.zip')..writeAsStringSync('hello');
      await expectLater(s.restore(notZip), throwsA(isA<BackupException>()));
      await expectLater(
        s.restore(await craft({'backup.json': manifest(2)})),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
      expect(s.isBusy.value, isFalse);
      expect(Directory('${root.path}/GPSCamera/Photos').existsSync(), isFalse);
    });

    test('ignores entries that point outside the backed-up folders', () async {
      final summary = await service(db).restore(
        await craft({
          'backup.json': manifest(),
          '../evil.jpg': [1],
          'Photos/../../evil.jpg': [1],
          'Photos/.hidden': [1],
          'Database/gps_camera.sqlite': [1],
          'Photos/IMG_ok.jpg': [5],
        }),
      );
      expect(summary.addedFiles, 1);
      expect(summary.skippedFiles, 4);
      expect(
        File('${root.path}/GPSCamera/Photos/IMG_ok.jpg').readAsBytesSync(),
        [5],
      );
      expect(File('${root.path}/evil.jpg').existsSync(), isFalse);
      expect(File('${root.path}/GPSCamera/evil.jpg').existsSync(), isFalse);

      expect(BackupService.isSafeRef('Reports/Report ঢাকা.pdf'), isTrue);
      expect(BackupService.isSafeRef('Photos/a/b.jpg'), isFalse);
      expect(BackupService.isSafeRef('/Photos/a.jpg'), isFalse);
    });
  });
}
