import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/theme_service.dart';
import 'package:gps_camera/features/backup/services/backup_service.dart';
import 'package:gps_camera/features/export/models/gallery_save_mode.dart';
import 'package:gps_camera/features/export/services/gallery_export_service.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';

class SettingsController extends GetxController {
  SettingsController(
    this._themeService,
    this._watermarkSettings,
    this._export,
    this._gallery,
    this.backup,
  );

  final ThemeService _themeService;
  final WatermarkSettingsStore _watermarkSettings;
  final GalleryExportService _export;
  final GalleryService _gallery;
  final BackupService backup;

  late final RxBool autoWatermark = _watermarkSettings.loadAutoWatermark().obs;

  /// Null until checked; false below Android 10.
  final RxnBool galleryAvailable = RxnBool();

  /// Photos copied so far by [copyExistingToGallery], or null when idle.
  final Rxn<BackupProgress> galleryProgress = Rxn<BackupProgress>();

  Rx<ThemeMode> get themeMode => _themeService.themeMode;

  Rx<GallerySaveMode> get gallerySaveMode => _export.mode;

  @override
  void onInit() {
    super.onInit();
    unawaited(
      _export.isAvailable().then((value) => galleryAvailable.value = value),
    );
  }

  Future<void> changeThemeMode(ThemeMode mode) =>
      _themeService.setThemeMode(mode);

  Future<void> setAutoWatermark(bool enabled) async {
    autoWatermark.value = enabled;
    await _watermarkSettings.saveAutoWatermark(enabled);
  }

  Future<void> setGallerySaveMode(GallerySaveMode mode) =>
      _export.setMode(mode);

  /// How many files [copyExistingToGallery] would copy, or null when the
  /// photos could not be listed.
  Future<int?> existingToCopy() async {
    try {
      return _export.plan(await _gallery.scan()).length;
    } catch (_) {
      return null;
    }
  }

  Future<GalleryExportSummary?> copyExistingToGallery() async {
    if (galleryProgress.value != null) return null;
    galleryProgress.value = const BackupProgress(0, 0);
    try {
      final index = await _gallery.scan();
      return await _export.exportExisting(
        index,
        onProgress: (done, total) =>
            galleryProgress.value = BackupProgress(done, total),
      );
    } catch (_) {
      return null;
    } finally {
      galleryProgress.value = null;
    }
  }
}
