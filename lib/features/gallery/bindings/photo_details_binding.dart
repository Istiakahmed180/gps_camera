import 'package:get/get.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/features/gallery/controllers/photo_details_controller.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';

/// Expects a [GalleryPhoto] as the route argument. The controller is tagged
/// with the photo id so stacked details screens stay independent.
class PhotoDetailsBinding extends Bindings {
  @override
  void dependencies() {
    final photo = Get.arguments as GalleryPhoto;
    Get.lazyPut(
      () => PhotoDetailsController(
        photo: photo,
        gallery: Get.find<GalleryController>(),
        service: Get.find<GalleryService>(),
        share: Get.find<ShareService>(),
      ),
      tag: photo.id,
    );
  }
}
