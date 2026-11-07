import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';

class GalleryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => GalleryService(Get.find<PhotoStorageService>()));
    Get.lazyPut(() => GalleryController(Get.find<GalleryService>()));
  }
}
