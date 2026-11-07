import 'package:get/get.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/gallery/controllers/photo_details_controller.dart';
import 'package:gps_camera/features/gallery/models/photo_library.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

/// Expects [PhotoDetailsArgs] as the route argument. The controller is
/// tagged with the photo id so stacked details screens stay independent.
class PhotoDetailsBinding extends Bindings {
  @override
  void dependencies() {
    final args = Get.arguments as PhotoDetailsArgs;
    Get.lazyPut(
      () => PhotoDetailsController(
        photo: args.photo,
        library: args.library,
        service: Get.find<GalleryService>(),
        share: Get.find<ShareService>(),
        projects: Get.find<ProjectRepository>(),
      ),
      tag: args.photo.id,
    );
  }
}
