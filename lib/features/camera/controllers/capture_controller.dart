import 'package:get/get.dart';

/// Named `CaptureController` to avoid clashing with the camera plugin's
/// `CameraController`, which arrives with the capture implementation.
class CaptureController extends GetxController {
  void close() => Get.back<void>();
}
