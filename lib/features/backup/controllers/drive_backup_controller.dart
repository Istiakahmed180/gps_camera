import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/backup/services/backup_service.dart';
import 'package:gps_camera/features/backup/services/drive_auth.dart';
import 'package:gps_camera/features/backup/services/drive_backup_service.dart';
import 'package:gps_camera/features/backup/services/drive_store.dart';
import 'package:gps_camera/features/watermark/services/logo_service.dart';
import 'package:http/http.dart' as http;

/// What Drive backup is doing now.
enum DriveActivity { idle, backingUp, restoring }

/// Google Drive backup for the whole app: the signed-in account, automatic
/// backup while the app is open, and manual backup and restore.
class DriveBackupController extends GetxService {
  DriveBackupController(
    this._service,
    this._settings, {
    DriveConnector? connector,
    Future<bool> Function()? onWifi,
    DateTime Function()? clock,
  }) : _connector = connector ?? DriveAuth(),
       _onWifi = onWifi ?? _platformOnWifi,
       _clock = clock ?? DateTime.now;

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
  }

  Future<void> setAuto(bool value) async {
    auto.value = value;
    await _settings.write(StorageKeys.driveAuto, value);
    if (value) unawaited(autoBackUp(force: true));
  }

  Future<void> setWifiOnly(bool value) async {
    wifiOnly.value = value;
    await _settings.write(StorageKeys.driveWifiOnly, value);
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
    activity.value = kind;
    problem.value = null;
    progress.value = null;
    DriveStore? store;
    try {
      store = await _connector.open(interactive: interactive);
      final result = await work(store);
      if (kind == DriveActivity.backingUp) {
        final now = _clock();
        lastBackup.value = now;
        await _settings.write(
          StorageKeys.driveLastBackup,
          now.toUtc().toIso8601String(),
        );
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
