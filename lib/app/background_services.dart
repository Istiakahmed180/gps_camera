import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';
import 'package:gps_camera/features/video/services/video_stamp_service.dart';
import 'package:gps_camera/features/video/services/video_service.dart';
import 'package:gps_camera/features/video/services/video_recovery.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/app/app.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/backup/services/backup_service.dart';
import 'package:gps_camera/features/settings/widgets/backup_actions.dart';
import 'package:gps_camera/features/export/services/gallery_export_service.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/location/services/details_backfill.dart';
import 'package:gps_camera/features/location/services/details_backfill_scheduler.dart';
import 'package:gps_camera/features/location/services/map_cache.dart';
import 'package:gps_camera/features/location/services/place_service.dart';
import 'package:gps_camera/features/location/services/static_map_service.dart';
import 'package:gps_camera/features/watermark/services/logo_service.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';

/// Work that runs while the app is open, outside any screen. Kept out of
/// [InitialBinding] so widget tests do not start timers.
abstract final class BackgroundServices {
  /// Finishes backup work interrupted when Android restarted the app while
  /// a file picker was open.
  static Future<void> _recoverBackupWork() async {
    final backup = Get.find<BackupService>();
    final work = await backup.pendingWork();
    if (work.restore == null && work.saved == null) return;
    // Wait for the first screen, so the message has somewhere to show.
    BuildContext? context;
    for (var i = 0; i < 50 && context == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final c = Get.context;
      if (c != null && c.mounted && Get.overlayContext != null) context = c;
    }
    if (context == null || !context.mounted) return;
    final saved = work.saved;
    if (saved != null) {
      appMessenger.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            saved == BackupSaveOutcome.saved
                ? 'Your backup was saved.'.tr
                : ('The backup could not be saved. Create it again in '
                          'Settings.')
                      .tr,
          ),
        ),
      );
    }
    final restore = work.restore;
    if (restore != null) {
      await BackupActions(service: backup)
          .restoreFile(context, restore, afterRestart: true);
    }
  }

  /// Saves a recording and makes stamped copies that Android interrupted
  /// by closing the app, then says so once there is a screen.
  static Future<void> _recoverVideos() async {
    try {
      final storage = Get.find<PhotoStorageService>();
      final settings = WatermarkSettingsStore(Get.find<StorageService>());
      final video = Get.find<VideoService>();
      final recovered = await VideoRecovery(
        storage: storage,
        saver: CaptureSaver(storage, video: video),
        stamper: Get.find<VideoStampService>(),
        gallery: Get.find<GalleryService>(),
        autoStamp: settings.loadAutoWatermark,
        config: settings.load,
        temporaryDirectory: getTemporaryDirectory,
        export: Get.find<GalleryExportService>(),
      ).run();
      if (recovered) {
        appMessenger.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              'A video that was interrupted when the app closed has been '
                      'saved.'
                  .tr,
            ),
          ),
        );
      }
    } catch (_) {
      // Tried again the next time the app starts.
    }
  }

  static Future<void> start() async {
    String? key;
    try {
      key = await const MethodChannel('co.tdevs.gps_camera/native')
          .invokeMethod<String>('mapKey');
    } catch (_) {
      key = null;
    }
    final maps = key == null || key.isEmpty
        ? null
        : StaticMapService(key, cache: Get.find<MapCache>());

    // Loads the logo and applies one picked just before a restart.
    Get.find<LogoService>();
    unawaited(_recoverBackupWork());
    unawaited(_recoverVideos());

    final storage = Get.find<PhotoStorageService>();
    final places = PlaceService();
    Get.put(
      DetailsBackfillScheduler(
        DetailsBackfill(
          storage: storage,
          gallery: Get.find<GalleryService>(),
          describe: places.describe,
          renderer: WatermarkRenderer(storage),
          fetchMap: maps?.fetch,
          export: Get.find<GalleryExportService>(),
        ),
      ),
      permanent: true,
    );
  }
}
