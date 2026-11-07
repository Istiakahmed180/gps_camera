import 'package:get/get.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

class GalleryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => GalleryController(
        Get.find<GalleryService>(),
        Get.find<ProjectRepository>(),
      ),
    );
  }
}
