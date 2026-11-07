import 'package:get/get.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';

class GalleryBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(GalleryController.new);
}
