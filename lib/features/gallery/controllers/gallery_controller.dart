import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';

class GalleryController extends GetxController {
  void openCamera() => Get.toNamed<void>(AppRoutes.camera);
}
