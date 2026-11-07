import 'package:get/get.dart';
import 'package:gps_camera/core/settings/app_preferences.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/camera/controllers/capture_controller.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/features/camera/services/volume_shutter.dart';
import 'package:gps_camera/features/export/services/gallery_export_service.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/camera/services/capture_enricher.dart';
import 'package:gps_camera/features/location/controllers/live_map_controller.dart';
import 'package:gps_camera/features/location/controllers/place_controller.dart';
import 'package:gps_camera/features/location/services/location_service.dart';
import 'package:gps_camera/features/location/services/map_cache.dart';
import 'package:gps_camera/features/location/services/place_service.dart';
import 'package:gps_camera/features/location/services/static_map_service.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';
import 'package:gps_camera/features/projects/controllers/active_project_controller.dart';
import 'package:gps_camera/features/projects/services/active_project_store.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

class CameraBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LocationService(Get.find<PermissionService>()));
    Get.lazyPut(
      () => LocationController(
        Get.find<LocationService>(),
        Get.find<PermissionService>(),
      ),
    );
    Get.lazyPut(
      () => ActiveProjectController(
        Get.find<ProjectRepository>(),
        ActiveProjectStore(Get.find<StorageService>()),
      ),
    );
    Get.lazyPut(
      () => PlaceController(Get.find<LocationController>(), PlaceService()),
    );
    Get.lazyPut(
      () => LiveMapController(
        Get.find<LocationController>(),
        serviceFor: (key) => StaticMapService(key, cache: Get.find<MapCache>()),
      ),
    );
    Get.lazyPut(() => WatermarkSettingsStore(Get.find<StorageService>()));
    Get.lazyPut(() {
      final storage = Get.find<PhotoStorageService>();
      final place = Get.find<PlaceController>();
      final map = Get.find<LiveMapController>();
      return CaptureController(
        Get.find<PermissionService>(),
        CaptureSaver(storage),
        Get.find<LocationController>(),
        assigner: Get.find<ActiveProjectController>(),
        quality: () => Get.find<AppPreferences>().photoQuality.value,
        timer: () => Get.find<AppPreferences>().captureTimer.value,
        volume: VolumeShutter(),
        volumeEnabled: () => Get.find<AppPreferences>().volumeShutter.value,
        note: () => Get.find<AppPreferences>().captureNote.value,
        postProcessor: CaptureEnricher(
          storage: storage,
          renderer: WatermarkRenderer(storage),
          settings: Get.find<WatermarkSettingsStore>(),
          placeFor: place.placeFor,
          grabMap: map.snapshot,
          gallery: Get.find<GalleryExportService>(),
        ),
      );
    });
  }
}
