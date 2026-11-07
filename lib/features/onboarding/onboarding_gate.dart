import 'dart:io';

import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';

/// Decides whether the first-launch introduction is shown.
abstract final class OnboardingGate {
  static bool isDone(StorageService storage) =>
      storage.read<bool>(StorageKeys.onboardingDone) ?? false;

  /// People who used the app before onboarding existed already know it:
  /// mark it done when there are saved settings or photos.
  static Future<void> skipForExistingUsers(
    StorageService storage,
    PhotoStorageService photos, {
    required bool hasSettings,
  }) async {
    if (isDone(storage)) return;
    var existing = hasSettings;
    if (!existing) {
      try {
        final root = await photos.rootDirectory();
        existing =
            await root.exists() &&
            await root.list(recursive: true).any((e) => e is File);
      } catch (_) {
        existing = false;
      }
    }
    if (existing) await storage.write(StorageKeys.onboardingDone, true);
  }
}
