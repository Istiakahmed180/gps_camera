import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/database/app_database.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/backup/services/backup_service.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/backup_recovery');
  Object? reply;

  late BackupService service;
  late AppDatabase db;

  setUpAll(() async {
    await mockPathProvider();
    await GetStorage.init('backup_recovery');
  });

  setUp(() {
    reply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'pendingBackup');
          if (reply is Exception) throw reply! as Exception;
          return reply;
        });
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(
      PhotoStorageService(),
      db,
      StorageService(GetStorage('backup_recovery')),
      channel: channel,
    );
  });

  tearDown(() => db.close());

  test('nothing pending', () async {
    final work = await service.pendingWork();
    expect(work.restore, isNull);
    expect(work.saved, isNull);
  });

  test('a backup chosen before the restart waits to be restored', () async {
    reply = {'restorePath': '/cache/backups/restore_pending.zip'};
    final work = await service.pendingWork();
    expect(work.restore!.path, '/cache/backups/restore_pending.zip');
    expect(work.saved, isNull);
  });

  test('reports whether the backup reached the chosen place', () async {
    reply = {'saveResult': 'saved'};
    expect((await service.pendingWork()).saved, BackupSaveOutcome.saved);
    reply = {'saveResult': 'failed'};
    expect((await service.pendingWork()).saved, BackupSaveOutcome.failed);
  });

  test('a platform error means nothing to recover', () async {
    reply = PlatformException(code: 'x');
    final work = await service.pendingWork();
    expect(work.restore, isNull);
    expect(work.saved, isNull);
  });
}
