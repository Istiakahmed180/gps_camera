import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/backup/controllers/drive_backup_controller.dart';
import 'package:gps_camera/features/backup/services/backup_service.dart';
import 'package:gps_camera/features/backup/services/drive_auth.dart';
import 'package:gps_camera/features/backup/services/drive_backup_service.dart';
import 'package:gps_camera/features/backup/services/drive_store.dart';

import 'helpers/db_fixtures.dart';
import 'helpers/test_env.dart';

/// Google Drive in memory: folders by id, files with content.
class FakeDrive implements DriveStore {
  final Map<String, ({String name, String? parent})> folders = {};
  final Map<String, ({String name, String parent, List<int> bytes})> stored =
      {};
  int uploads = 0;
  int _next = 0;
  bool closed = false;

  String _id() => 'id${_next++}';

  @override
  Future<String?> findFolder(String name, {String? parentId}) async {
    for (final MapEntry(:key, :value) in folders.entries) {
      if (value.name == name && value.parent == parentId) return key;
    }
    return null;
  }

  @override
  Future<String> folder(String name, {String? parentId}) async {
    final found = await findFolder(name, parentId: parentId);
    if (found != null) return found;
    final id = _id();
    folders[id] = (name: name, parent: parentId);
    return id;
  }

  @override
  Future<List<DriveEntry>> files(String folderId) async => [
    for (final MapEntry(:key, :value) in stored.entries)
      if (value.parent == folderId)
        DriveEntry(
          id: key,
          name: value.name,
          md5: md5.convert(value.bytes).toString(),
          size: value.bytes.length,
        ),
  ];

  @override
  Future<DriveEntry> upload(
    File file,
    String name,
    String folderId, {
    String? replaceId,
  }) async {
    uploads++;
    final id = replaceId ?? _id();
    stored[id] = (
      name: name,
      parent: folderId,
      bytes: await file.readAsBytes(),
    );
    return DriveEntry(id: id, name: name);
  }

  @override
  Future<void> download(String id, File target) =>
      target.writeAsBytes(stored[id]!.bytes);

  @override
  void close() => closed = true;

  /// `Photos/IMG_1.jpg` → its bytes, under "Locaproof Backup".
  Map<String, List<int>> get tree {
    final out = <String, List<int>>{};
    for (final f in stored.values) {
      final parent = folders[f.parent]!;
      final path = parent.name == DriveBackupService.rootFolder
          ? f.name
          : '${parent.name}/${f.name}';
      out[path] = f.bytes;
    }
    return out;
  }
}

class FakeConnector implements DriveConnector {
  FakeConnector(this.drive);

  final FakeDrive drive;
  bool configured = true;
  Object? openError;
  int signIns = 0;
  final List<bool> opens = [];

  @override
  bool get isConfigured => configured;

  @override
  Future<String> signIn() async {
    signIns++;
    return 'me@example.com';
  }

  @override
  Future<DriveStore> open({bool interactive = false}) async {
    opens.add(interactive);
    if (openError != null) throw openError!;
    return drive;
  }

  String? allowedBefore;

  @override
  Future<String?> restoreSignIn() async => allowedBefore;

  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory temp;
  late DbFixture db;
  late StorageService settings;
  late BackupService backup;
  late DriveBackupService service;

  setUpAll(() async {
    await mockPathProvider();
    await GetStorage.init('drive_test');
  });

  setUp(() async {
    final box = GetStorage('drive_test');
    await box.erase();
    settings = StorageService(box);
    root = await PhotoStorageService().rootDirectory();
    if (await root.exists()) await root.delete(recursive: true);
    temp = await Directory.systemTemp.createTemp('drive_tmp');
    db = DbFixture();
    backup = BackupService(PhotoStorageService(), db.db, settings);
    service = DriveBackupService(
      backup,
      PhotoStorageService(),
      tempDirectory: () async => temp,
    );
  });

  tearDown(() async {
    await db.close();
    Get.reset();
  });

  File write(String ref, String content) {
    final file = File('${root.path}/$ref')..createSync(recursive: true);
    return file..writeAsStringSync(content);
  }

  group('backup', () {
    test('sends every file and the projects to Drive', () async {
      write('Photos/IMG_1.jpg', 'photo one');
      write('Photos/IMG_1.json', '{"note":"a"}');
      write('Watermarked/IMG_1_wm.jpg', 'stamped');
      await db.repo.create(name: 'Block C');
      final drive = FakeDrive();
      final progress = <(int, int)>[];

      final result = await service.backUp(
        drive,
        onProgress: (d, t) => progress.add((d, t)),
      );

      expect(result.uploaded, 3);
      expect(drive.tree.keys, {
        'Photos/IMG_1.jpg',
        'Photos/IMG_1.json',
        'Watermarked/IMG_1_wm.jpg',
        'backup.json',
      });
      final manifest = jsonDecode(
        utf8.decode(drive.tree['backup.json']!),
      ) as Map<String, dynamic>;
      expect(manifest['format'], BackupService.format);
      expect((manifest['projects'] as List).single['name'], 'Block C');
      expect(progress.last, (3, 3));
    });

    test('sends only what is new or changed the next time', () async {
      write('Photos/IMG_1.jpg', 'photo one');
      final details = write('Photos/IMG_1.json', '{"note":"a"}');
      final drive = FakeDrive();
      await service.backUp(drive);
      final first = drive.uploads;

      write('Photos/IMG_2.jpg', 'photo two');
      details.writeAsStringSync('{"note":"b"}');
      final result = await service.backUp(drive);

      expect(result.uploaded, 2, reason: 'new photo and edited details');
      expect(result.unchanged, 1);
      // The new photo, the details file, and the manifest before and after.
      expect(drive.uploads - first, 4);
      expect(utf8.decode(drive.tree['Photos/IMG_1.json']!), '{"note":"b"}');
      expect(
        drive.stored.values.where((f) => f.name == 'IMG_1.json'),
        hasLength(1),
        reason: 'replaced, not duplicated',
      );
    });

    test('a photo deleted from the phone stays in Drive', () async {
      final photo = write('Photos/IMG_1.jpg', 'photo one');
      final drive = FakeDrive();
      await service.backUp(drive);
      photo.deleteSync();
      await service.backUp(drive);
      expect(drive.tree, contains('Photos/IMG_1.jpg'));
    });
  });

  group('restore', () {
    test('adds what the phone lacks and keeps what it has', () async {
      write('Photos/IMG_1.jpg', 'photo one');
      write('Photos/IMG_2.jpg', 'photo two');
      await db.repo.create(name: 'Block C');
      final drive = FakeDrive();
      await service.backUp(drive);

      // A reinstall: everything gone, then one photo taken again.
      await root.delete(recursive: true);
      await db.close();
      db = DbFixture();
      backup = BackupService(PhotoStorageService(), db.db, settings);
      service = DriveBackupService(
        backup,
        PhotoStorageService(),
        tempDirectory: () async => temp,
      );
      write('Photos/IMG_2.jpg', 'kept as it is');

      final result = await service.restore(drive);

      expect(result.addedFiles, 1);
      expect(result.addedPhotos, 1);
      expect(result.addedProjects, 1);
      expect(
        File('${root.path}/Photos/IMG_1.jpg').readAsStringSync(),
        'photo one',
      );
      expect(
        File('${root.path}/Photos/IMG_2.jpg').readAsStringSync(),
        'kept as it is',
      );
      expect(
        root.listSync(recursive: true).where((e) => e.path.endsWith('.tmp')),
        isEmpty,
      );
    });

    test('an account without a backup says so and creates nothing', () async {
      final drive = FakeDrive();
      await expectLater(service.restore(drive), throwsA(isA<DriveNoBackup>()));
      expect(drive.folders, isEmpty);
    });

    test('never runs alongside a ZIP backup or restore', () async {
      write('Photos/IMG_1.jpg', 'photo one');
      final zip = backup.create();
      await expectLater(
        service.backUp(FakeDrive()),
        throwsA(isA<BackupException>()),
      );
      await backup.discard((await zip).file);
    });

    test('ignores unsafe names in Drive', () async {
      final drive = FakeDrive();
      final rootId = await drive.folder(DriveBackupService.rootFolder);
      final photos = await drive.folder('Photos', parentId: rootId);
      drive.stored['x'] = (name: '../evil.jpg', parent: photos, bytes: [1]);
      drive.stored['y'] = (name: '.hidden', parent: photos, bytes: [1]);

      final result = await service.restore(drive);
      expect(result.addedFiles, 0);
      expect(File('${root.path}/evil.jpg').existsSync(), isFalse);
    });
  });

  group('controller', () {
    late FakeDrive drive;
    late FakeConnector connector;
    late bool wifi;
    late DateTime now;

    DriveBackupController controller() => DriveBackupController(
      service,
      settings,
      connector: connector,
      onWifi: () async => wifi,
      clock: () => now,
    );

    setUp(() {
      drive = FakeDrive();
      connector = FakeConnector(drive);
      wifi = true;
      now = DateTime(2026, 11, 14, 10);
    });

    test('signing in remembers the account and backs up', () async {
      write('Photos/IMG_1.jpg', 'photo one');
      final c = controller();
      await c.signIn();
      expect(c.account.value, 'me@example.com');
      expect(settings.read<String>(StorageKeys.driveAccount), 'me@example.com');
      expect(drive.tree, contains('Photos/IMG_1.jpg'));
      expect(c.lastBackup.value, now);
      expect(drive.closed, isTrue);
      expect(controller().account.value, 'me@example.com');
    });

    test('automatic backup waits for Wi-Fi and is spaced out', () async {
      write('Photos/IMG_1.jpg', 'photo one');
      await settings.write(StorageKeys.driveAccount, 'me@example.com');
      final c = controller();

      wifi = false;
      await c.autoBackUp();
      expect(c.waitingForWifi.value, isTrue);
      expect(connector.opens, isEmpty);

      wifi = true;
      await c.autoBackUp();
      expect(connector.opens, [false], reason: 'never shows Google screens');

      now = now.add(const Duration(minutes: 5));
      await c.autoBackUp();
      expect(connector.opens, hasLength(1), reason: 'too soon');

      await c.autoBackUp(force: true);
      expect(connector.opens, hasLength(2), reason: 'after the camera');

      // Allowing mobile data starts a run right away.
      wifi = false;
      await c.setWifiOnly(false);
      for (var i = 0; i < 100 && connector.opens.length < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      while (c.isBusy) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(connector.opens, hasLength(3));
      now = now.add(DriveBackupController.autoEvery);
      await c.autoBackUp();
      expect(connector.opens, hasLength(4));
    });

    test('does nothing when signed out, off or not set up', () async {
      final c = controller();
      await c.autoBackUp(force: true);
      expect(await c.backUpNow(), isNull);
      expect(connector.opens, isEmpty);

      await settings.write(StorageKeys.driveAccount, 'me@example.com');
      final off = controller();
      await off.setAuto(false);
      await off.autoBackUp(force: true);
      expect(connector.opens, isEmpty);

      connector.configured = false;
      final notSetUp = controller();
      await notSetUp.autoBackUp(force: true);
      expect(connector.opens, isEmpty);
    });

    test('a failure is reported and the next run can go', () async {
      await settings.write(StorageKeys.driveAccount, 'me@example.com');
      final c = controller();
      connector.openError = const DriveAuthException(
        DriveAuthProblem.signedOut,
      );
      expect(await c.backUpNow(), isNull);
      expect(c.problem.value, 'Sign in to Google again to keep backing up.');
      expect(c.activity.value, DriveActivity.idle);

      connector.openError = const SocketException('offline');
      await c.backUpNow();
      expect(
        c.problem.value,
        'Google Drive could not be reached. Check the internet connection.',
      );

      connector.openError = null;
      expect(await c.backUpNow(), isNotNull);
      expect(c.problem.value, isNull);
    });

    test('a sign-in cut off by Android finishes on the next start', () async {
      write('Photos/IMG_1.jpg', 'photo one');
      // The app was closed behind Google's permission screen.
      await settings.write(StorageKeys.driveSignInPending, true);
      connector.allowedBefore = 'me@example.com';

      final c = controller()..onInit();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(c.account.value, 'me@example.com');
      expect(connector.opens, [false], reason: 'no Google screens');
      expect(drive.tree, contains('Photos/IMG_1.jpg'));
      expect(settings.read<bool>(StorageKeys.driveSignInPending), isNull);
    });

    test(
      'an unfinished sign-in that Google does not know asks again',
      () async {
        await settings.write(StorageKeys.driveSignInPending, true);
        final c = controller()..onInit();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(c.isSignedIn, isFalse);
        expect(
          c.problem.value,
          'Google sign-in did not finish. Tap Sign in again.',
        );
      },
    );

    test('leaving Wi-Fi pauses an automatic backup quietly', () async {
      write('Photos/IMG_1.jpg', 'photo one');
      write('Photos/IMG_2.jpg', 'photo two');
      await settings.write(StorageKeys.driveAccount, 'me@example.com');
      final c = controller();
      var checks = 0;
      wifi = true;
      // Wi-Fi drops after the first upload.
      final onWifi = DriveBackupController(
        service,
        settings,
        connector: connector,
        onWifi: () async => checks++ < 2,
        clock: () => now,
      );
      await onWifi.autoBackUp(force: true);
      expect(onWifi.waitingForWifi.value, isTrue);
      expect(onWifi.problem.value, isNull);
      expect(drive.tree, contains('Photos/IMG_1.jpg'));
      expect(drive.tree, isNot(contains('Photos/IMG_2.jpg')));
      expect(c.isBusy, isFalse);
    });

    test('signing out keeps Drive and stops backing up', () async {
      await settings.write(StorageKeys.driveAccount, 'me@example.com');
      final c = controller();
      await c.signOut();
      expect(c.isSignedIn, isFalse);
      expect(settings.read<String>(StorageKeys.driveAccount), isNull);
    });
  });
}
