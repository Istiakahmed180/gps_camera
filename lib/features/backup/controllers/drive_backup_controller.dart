import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/backup/services/background_backup.dart';
import 'package:gps_camera/features/backup/services/backup_service.dart';
import 'package:gps_camera/features/backup/services/drive_auth.dart';
import 'package:gps_camera/features/backup/services/drive_backup_service.dart';
import 'package:gps_camera/features/backup/services/drive_store.dart';
import 'package:gps_camera/features/backup/services/drive_sync_state.dart';
import 'package:gps_camera/features/watermark/services/logo_service.dart';
import 'package:http/http.dart' as http;

/// What Drive backup is doing now.
enum DriveActivity { idle, backingUp, restoring }

/// Google Drive backup for the whole app: the signed-in account, automatic
/// backup while the app is open, and manual backup and restore.
class DriveBackupController extends GetxService with WidgetsBindingObserver {
  DriveBackupController(
    this._service,
    this._settings, {
    DriveConnector? connector,
    Future<bool> Function()? onWifi,
    DateTime Function()? clock,
    BackgroundBackupScheduler? scheduler,
    DriveSyncState? state,
    Future<bool> Function()? backgroundAllowedCheck,
    BackupKeepAlive? keepAlive,
  }) : _keepAlive = keepAlive ?? BackupKeepAlive(),
       _backgroundAllowedCheck =
           backgroundAllowedCheck ?? _platformBackgroundAllowed,
       _connector = connector ?? DriveAuth(),
       _onWifi = onWifi ?? _platformOnWifi,
       _clock = clock ?? DateTime.now,
       _scheduler = scheduler ?? BackgroundBackupScheduler(),
       _state = state ?? DriveSyncState();

  final BackgroundBackupScheduler _scheduler;
  final Future<bool> Function() _backgroundAllowedCheck;
  final BackupKeepAlive _keepAlive;

  static const MethodChannel _native = MethodChannel(
    'com.locaproof.app/native',
  );

  /// False when the phone's battery saving may stop backup while the app
  /// is closed (OPPO, Realme, OnePlus, Xiaomi and others freeze it).
  final RxBool backgroundAllowed = true.obs;

  Future<void> refreshBackgroundAllowed() async {
    try {
      backgroundAllowed.value = await _backgroundAllowedCheck();
    } catch (_) {
      backgroundAllowed.value = true;
    }
  }

  /// Opens this app's system settings, where Battery lets it run in the
  /// background. Checked again when the user comes back.
  Future<void> openBackgroundSettings() async {
    try {
      await _native.invokeMethod<bool>('openBackgroundSettings');
    } catch (_) {}
  }

  static Future<bool> _platformBackgroundAllowed() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return await _native.invokeMethod<bool>('backgroundAllowed') ?? true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshBackgroundAllowed());
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  final DriveSyncState _state;

  final DriveBackupService _service;
  final StorageService _settings;
  final DriveConnector _connector;
  final Future<bool> Function() _onWifi;
  final DateTime Function() _clock;

  /// Automatic runs at most this often, unless something new was captured.
  static const Duration autoEvery = Duration(minutes: 15);

  late final RxnString account = RxnString(
    _settings.read<String>(StorageKeys.driveAccount),
  );
  late final RxBool auto =
      (_settings.read<bool>(StorageKeys.driveAuto) ?? true).obs;
  late final RxBool wifiOnly =
      (_settings.read<bool>(StorageKeys.driveWifiOnly) ?? true).obs;
  late final Rxn<DateTime> lastBackup = Rxn<DateTime>(
    DateTime.tryParse(
      _settings.read<String>(StorageKeys.driveLastBackup) ?? '',
    ),
  );

  final Rx<DriveActivity> activity = DriveActivity.idle.obs;

  /// Files handled and total, while running.
  final Rxn<(int, int)> progress = Rxn<(int, int)>();

  /// Why the last run stopped, already translated; null after a success.
  final RxnString problem = RxnString();

  /// True while an automatic backup waits for Wi-Fi.
  final RxBool waitingForWifi = false.obs;

  DateTime? _lastAutoAttempt;

  bool get isConfigured => _connector.isConfigured;

  @override
  void onInit() {
    super.onInit();
    if (_settings.read<bool>(StorageKeys.driveSignInPending) ?? false) {
      unawaited(_finishInterruptedSignIn());
    }
    unawaited(refreshLastBackup());
    unawaited(_syncSchedule());
    unawaited(refreshBackgroundAllowed());
    WidgetsBinding.instance.addObserver(this);
  }

  /// The app went to the background: a background run soon finishes what
  /// this one could not (Android may close the app any moment now).
  ///
  /// The app's own process finishes the backup first: Android started a
  /// service with a "Backing up" notification as the app was left, which
  /// keeps phones from freezing it. The service stops when this is done.
  Future<void> appLeft() async {
    if (!isSignedIn || !auto.value || !isConfigured) {
      await _keepAlive.stop();
      return;
    }
    try {
      await _scheduler.runSoon(wifiOnly: wifiOnly.value);
    } catch (_) {}
    try {
      await autoBackUp(force: true);
      // A backup started earlier (after the camera) may still be running.
      while (isBusy) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    } finally {
      await _keepAlive.stop();
    }
  }

  /// Picks up a backup the background job made while the app was closed.
  Future<void> refreshLastBackup() async {
    final fromJob = await _state.lastBackup();
    final shown = lastBackup.value;
    if (fromJob != null && (shown == null || fromJob.isAfter(shown))) {
      lastBackup.value = fromJob.toLocal();
    }
  }

  /// The background job runs only while signed in with automatic backup
  /// on, with the current Wi-Fi setting.
  Future<void> _syncSchedule() async {
    final on = isSignedIn && auto.value && isConfigured;
    await _keepAlive.setWanted(on);
    try {
      if (on) {
        await _scheduler.schedule(wifiOnly: wifiOnly.value);
      } else {
        await _scheduler.cancel();
      }
    } catch (_) {
      // Backup still runs while the app is open.
    }
  }

  /// Android may close the app while Google's account or permission screen
  /// is open; the sign-in then finishes here on the next start, silently.
  Future<void> _finishInterruptedSignIn() async {
    await _settings.remove(StorageKeys.driveSignInPending);
    if (isSignedIn || !isConfigured) return;
    String? email;
    try {
      email = await _connector.restoreSignIn();
    } catch (_) {
      email = null;
    }
    if (email == null) {
      problem.value = 'Google sign-in did not finish. Tap Sign in again.'.tr;
      return;
    }
    account.value = email;
    await _settings.write(StorageKeys.driveAccount, email);
    unawaited(_syncSchedule());
    await _run(DriveActivity.backingUp, interactive: false, (store) {
      return _service.backUp(store, onProgress: _progress);
    });
  }

  bool get isSignedIn => account.value != null;

  bool get isBusy => activity.value != DriveActivity.idle;

  /// Shows Google's sign-in, then backs up at once.
  Future<void> signIn() async {
    problem.value = null;
    // Remembered in case Android closes the app behind Google's screens.
    await _settings.write(StorageKeys.driveSignInPending, true);
    try {
      final email = await _connector.signIn();
      account.value = email;
      await _settings.write(StorageKeys.driveAccount, email);
      unawaited(_syncSchedule());
      // For the "Backing up" notification after the app is left.
      unawaited(_keepAlive.askToNotify());
    } catch (e) {
      problem.value = _message(e);
      return;
    } finally {
      await _settings.remove(StorageKeys.driveSignInPending);
    }
    await backUpNow();
  }

  /// Stops backing up. What is in Drive stays there.
  Future<void> signOut() async {
    await _connector.signOut();
    account.value = null;
    problem.value = null;
    waitingForWifi.value = false;
    await _settings.remove(StorageKeys.driveAccount);
    await _syncSchedule();
  }

  Future<void> setAuto(bool value) async {
    auto.value = value;
    await _settings.write(StorageKeys.driveAuto, value);
    await _syncSchedule();
    if (value) unawaited(autoBackUp(force: true));
  }

  Future<void> setWifiOnly(bool value) async {
    wifiOnly.value = value;
    await _settings.write(StorageKeys.driveWifiOnly, value);
    await _syncSchedule();
    if (!value) unawaited(autoBackUp(force: true));
  }

  /// Backs up now, on any connection, asking Google for permission again
  /// if it wants. Returns the result, or null when it did not finish
  /// ([problem] says why).
  Future<DriveBackupResult?> backUpNow() =>
      _run(DriveActivity.backingUp, interactive: true, (store) {
        return _service.backUp(store, onProgress: _progress);
      });

  /// Runs on its own: when the app opens or comes back, and after the
  /// camera closes. Skips quietly when turned off, signed out, already
  /// running, recently done (unless [force]) or not on Wi-Fi when required.
  Future<void> autoBackUp({bool force = false}) async {
    unawaited(refreshLastBackup());
    // Also waits while a ZIP backup or restore runs.
    if (!auto.value || !isSignedIn || !isConfigured || isBusy) return;
    if (_service.isBusy) return;
    final now = _clock();
    final last = _lastAutoAttempt;
    if (!force && last != null && now.difference(last) < autoEvery) return;
    if (wifiOnly.value && !await _onWifi()) {
      waitingForWifi.value = true;
      return;
    }
    waitingForWifi.value = false;
    _lastAutoAttempt = now;
    await _run(DriveActivity.backingUp, interactive: false, (store) {
      return _service.backUp(
        store,
        onProgress: _progress,
        // Checked before every file: leaving Wi-Fi stops the run.
        canContinue: () async => !wifiOnly.value || await _onWifi(),
      );
    });
  }

  /// Adds to this phone what is in Drive and missing here.
  Future<DriveRestoreResult?> restore() async {
    final result = await _run(DriveActivity.restoring, interactive: true, (
      store,
    ) {
      return _service.restore(store, onProgress: _progress);
    });
    // A restored logo should show without restarting the app.
    if (result != null && Get.isRegistered<LogoService>()) {
      unawaited(Get.find<LogoService>().reload());
    }
    return result;
  }

  void _progress(int done, int total) => progress.value = (done, total);

  Future<T?> _run<T>(
    DriveActivity kind,
    Future<T> Function(DriveStore store) work, {
    required bool interactive,
  }) async {
    if (isBusy || !isSignedIn) return null;
    // The background job may be backing up right now.
    if (!await _state.lock()) {
      if (interactive) problem.value = 'A backup is already in progress.'.tr;
      return null;
    }
    activity.value = kind;
    problem.value = null;
    progress.value = null;
    DriveStore? store;
    try {
      store = await _connector.open(account.value!, interactive: interactive);
      final result = await work(store);
      if (kind == DriveActivity.backingUp) {
        final now = _clock();
        lastBackup.value = now;
        await _settings.write(
          StorageKeys.driveLastBackup,
          now.toUtc().toIso8601String(),
        );
        await _state.setLastBackup(now);
      }
      return result;
    } on DriveBackupPaused {
      // Not a problem: it goes on once back on Wi-Fi.
      waitingForWifi.value = true;
      return null;
    } catch (e) {
      problem.value = _message(e);
      return null;
    } finally {
      await _state.unlock();
      store?.close();
      activity.value = DriveActivity.idle;
      progress.value = null;
    }
  }

  static String _message(Object e) => switch (e) {
    DriveNoBackup() =>
      'No Locaproof backup was found in this Google account.'.tr,
    BackupException(:final message) => message.tr,
    DriveAuthException(problem: DriveAuthProblem.notConfigured) =>
      'Google Drive backup is not set up in this version of the app.'.tr,
    DriveAuthException(problem: DriveAuthProblem.cancelled) =>
      'Google sign-in was cancelled.'.tr,
    DriveAuthException(problem: DriveAuthProblem.signedOut) =>
      'Sign in to Google again to keep backing up.'.tr,
    DriveAuthException() => 'Google sign-in failed. Try again later.'.tr,
    drive.DetailedApiRequestError(status: 401) =>
      'Sign in to Google again to keep backing up.'.tr,
    drive.DetailedApiRequestError(status: 403, :final message)
        when message?.toLowerCase().contains('quota') ?? false =>
      'Your Google Drive is full.'.tr,
    SocketException() || http.ClientException() || TimeoutException() =>
      'Google Drive could not be reached. Check the internet connection.'.tr,
    FileSystemException() =>
      'A file could not be read or written on this phone.'.tr,
    _ => 'The backup could not be completed. Try again later.'.tr,
  };

  static Future<bool> _platformOnWifi() async {
    try {
      final kinds = await Connectivity().checkConnectivity();
      return kinds.contains(ConnectivityResult.wifi) ||
          kinds.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }
}

/// The "Backing up to Google Drive" service the app starts as it is left
/// (see `BackupKeepAliveService` on Android).
class BackupKeepAlive {
  static const MethodChannel _channel = MethodChannel(
    'com.locaproof.app/native',
  );

  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  /// Whether leaving the app should start it: Drive backup is on.
  Future<void> setWanted(bool wanted) async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('setBackupKeepAlive', {
        'wanted': wanted,
        'title': 'Backing up to Google Drive'.tr,
        'text': 'Locaproof is finishing your backup.'.tr,
        'channel': 'Google Drive backup'.tr,
      });
    } catch (_) {}
  }

  Future<void> stop() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('stopBackupKeepAlive');
    } catch (_) {}
  }

  /// Android 13+ asks before an app shows notifications; without it the
  /// service still works, only its notification is hidden.
  Future<void> askToNotify() async {
    if (!_android) return;
    try {
      await Permission.notification.request();
    } catch (_) {}
  }
}
