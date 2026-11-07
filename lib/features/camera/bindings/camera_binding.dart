import 'package:get/get.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/camera/controllers/capture_controller.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/location/services/location_service.dart';
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
      () => CaptureController(
        Get.find<PermissionService>(),
        CaptureSaver(Get.find<PhotoStorageService>()),
        Get.find<LocationController>(),
        assigner: Get.find<ActiveProjectController>(),
      ),
    );
  }
}
