import 'package:get/get.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/controllers/capture_controller.dart';

class CameraBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CaptureController(
        Get.find<PermissionService>(),
        Get.find<PhotoStorageService>(),
      ),
    );
  }
}
