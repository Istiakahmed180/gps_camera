import 'package:get/get.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/projects/controllers/project_details_controller.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

/// Expects the project id as the route argument.
class ProjectDetailsBinding extends Bindings {
  @override
  void dependencies() {
    final id = Get.arguments as String;
    Get.lazyPut(
      () => ProjectDetailsController(
        projectId: id,
        repo: Get.find<ProjectRepository>(),
        gallery: Get.find<GalleryService>(),
      ),
    );
  }
}
