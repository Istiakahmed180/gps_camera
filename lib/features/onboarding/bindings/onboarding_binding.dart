import 'package:get/get.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/onboarding/controllers/onboarding_controller.dart';

class OnboardingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => OnboardingController(
        Get.find<PermissionService>(),
        Get.find<StorageService>(),
      ),
    );
  }
}
