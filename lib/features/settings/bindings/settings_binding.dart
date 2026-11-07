import 'package:get/get.dart';
import 'package:gps_camera/core/services/theme_service.dart';
import 'package:gps_camera/features/settings/controllers/settings_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SettingsController(Get.find<ThemeService>()));
  }
}
