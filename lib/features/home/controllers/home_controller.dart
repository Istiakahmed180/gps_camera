import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';

class HomeController extends GetxController {
  void openCamera() => Get.toNamed<void>(AppRoutes.camera);

  void openGallery() => Get.toNamed<void>(AppRoutes.gallery);

  void openProjects() => Get.toNamed<void>(AppRoutes.projects);

  void openSettings() => Get.toNamed<void>(AppRoutes.settings);

  void openReports() => Get.toNamed<void>(AppRoutes.reports);
}
