import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/database/app_database.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/backup/services/backup_service.dart';
import 'package:gps_camera/features/backup/services/drive_auth.dart';
import 'package:gps_camera/features/backup/services/drive_backup_service.dart';
import 'package:gps_camera/features/backup/services/drive_store.dart';
import 'package:gps_camera/features/backup/services/drive_sync_state.dart';
import 'package:workmanager/workmanager.dart';

/// Schedules Google Drive backup to run while the app is closed. Android
/// picks the moment (often overnight, on charge), never more often than
/// [every], only with enough battery and, when asked, only on Wi-Fi.
class BackgroundBackupScheduler {
  static const String uniqueName = 'locaproof-drive-backup';
  static const String taskName = 'drive-backup';
  static const Duration every = Duration(hours: 6);

  /// Once per app start, before anything is scheduled.
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    await Workmanager().initialize(backgroundBackupDispatcher);
  }

  Future<void> schedule({required bool wifiOnly}) async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: every,
      constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
      // Changed settings (Wi-Fi only) apply to the job already scheduled.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  /// One run as soon as the app is left, to finish what the open app had
  /// no time to send (photos taken just before closing it). Expedited, so
  /// battery managers that freeze closed apps (OPPO, Realme, OnePlus…)
  /// let it finish; when Android's daily allowance for that is used up it
  /// runs as ordinary background work instead.
  Future<void> runSoon({required bool wifiOnly}) async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerOneOffTask(
      soonName,
      taskName,
      constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
      ),
      // Already waiting to run: that run will see the new photos too.
      existingWorkPolicy: ExistingWorkPolicy.keep,
      expedited: true,
      outOfQuotaPolicy: OutOfQuotaPolicy.runAsNonExpeditedWorkRequest,
    );
  }

  static const String soonName = 'locaproof-drive-backup-soon';

  Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await Workmanager().cancelByUniqueName(uniqueName);
    await Workmanager().cancelByUniqueName(soonName);
  }
}

/// Entry point Android calls in a fresh background isolate.
@pragma('vm:entry-point')
void backgroundBackupDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != BackgroundBackupScheduler.taskName) return true;
    try {
      await runBackgroundBackup();
    } catch (e) {
      // Tried again at the next scheduled time; never a retry storm.
      _log('failed: $e');
    }
    return true;
  });
}

/// One background backup: the same as the app's automatic backup, with no
/// screens. Settings are only read here; the result goes to
/// [DriveSyncState] so the app's settings file is never written from two
/// places at once.
@visibleForTesting
Future<void> runBackgroundBackup({
  Future<DriveStore> Function(String email)? openDrive,
  Future<bool> Function()? onWifi,
  AppDatabase? database,
  StorageService? settings,
  DriveSyncState? state,
  Duration lockWait = const Duration(minutes: 2),
  Duration lockRetry = const Duration(seconds: 2),
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  if (settings == null) await GetStorage.init();
  final store = settings ?? StorageService(GetStorage());

  final email = store.read<String>(StorageKeys.driveAccount);
  final auto = store.read<bool>(StorageKeys.driveAuto) ?? true;
  final wifiOnly = store.read<bool>(StorageKeys.driveWifiOnly) ?? true;
  if (email == null || !auto) {
    _log('skipped: signed out or automatic backup off');
    return;
  }
  final checkWifi = onWifi ?? _onWifi;
  if (wifiOnly && !await checkWifi()) {
    _log('skipped: not on Wi-Fi');
    return;
  }

  final sync = state ?? DriveSyncState();
  // The app may be backing up right now (it was just left): wait for it,
  // then send what it did not get to.
  final until = DateTime.now().add(lockWait);
  var locked = await sync.lock();
  while (!locked && DateTime.now().isBefore(until)) {
    await Future<void>.delayed(lockRetry);
    locked = await sync.lock();
  }
  if (!locked) {
    _log('skipped: another backup holds the lock');
    return;
  }
  final db = database ?? AppDatabase();
  DriveStore? drive;
  try {
    drive = await (openDrive ?? DriveAuth.openForAccount)(email);
    final service = DriveBackupService(
      BackupService(PhotoStorageService(), db, store),
      PhotoStorageService(),
    );
    final result = await service.backUp(
      drive,
      canContinue: wifiOnly ? checkWifi : null,
    );
    await sync.setLastBackup(DateTime.now());
    _log('done: ${result.uploaded} sent, ${result.unchanged} already there');
  } on DriveBackupPaused {
    // Left Wi-Fi; the next run goes on.
    _log('paused: left Wi-Fi');
  } finally {
    // First, so nothing below can leave the lock held.
    await sync.unlock();
    drive?.close();
    if (database == null) {
      try {
        await db.close();
      } catch (_) {}
    }
  }
}

Future<bool> _onWifi() async {
  try {
    final kinds = await Connectivity().checkConnectivity();
    return kinds.contains(ConnectivityResult.wifi) ||
        kinds.contains(ConnectivityResult.ethernet);
  } catch (_) {
    return false;
  }
}

/// One line in the phone's log (`adb logcat | grep LocaproofBackup`), the
/// only way to see what a run with no screen did.
void _log(String message) {
  // ignore: avoid_print
  print('LocaproofBackup: $message');
}
