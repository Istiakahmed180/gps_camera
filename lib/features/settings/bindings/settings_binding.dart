import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/settings/app_preferences.dart';
import 'package:gps_camera/features/location/services/details_backfill_scheduler.dart';
import 'package:gps_camera/features/location/services/map_cache.dart';
import 'package:gps_camera/features/settings/services/storage_usage.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/core/services/theme_service.dart';
import 'package:gps_camera/features/backup/services/backup_service.dart';
import 'package:gps_camera/features/export/services/gallery_export_service.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/settings/controllers/settings_controller.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => SettingsController(
        Get.find<ThemeService>(),
        WatermarkSettingsStore(Get.find<StorageService>()),
        Get.find<GalleryExportService>(),
        Get.find<GalleryService>(),
        Get.find<BackupService>(),
        Get.find<AppPreferences>(),
        StorageUsage(Get.find<PhotoStorageService>(), Get.find<MapCache>()),
        details: Get.isRegistered<DetailsBackfillScheduler>()
            ? Get.find<DetailsBackfillScheduler>()
            : null,
      ),
    );
  }
}
