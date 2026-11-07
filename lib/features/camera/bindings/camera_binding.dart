import 'package:get/get.dart';
import 'package:gps_camera/features/camera/controllers/capture_controller.dart';

class CameraBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(CaptureController.new);
}
