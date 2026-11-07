import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/projects/controllers/project_edit_controller.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

/// Expects the [Project] to edit as the route argument, or none to create.
class ProjectEditBinding extends Bindings {
  @override
  void dependencies() {
    final existing = Get.arguments as Project?;
    Get.lazyPut(
      () => ProjectEditController(
        existing: existing,
        repo: Get.find<ProjectRepository>(),
        gallery: Get.find<GalleryService>(),
        storage: Get.find<PhotoStorageService>(),
      ),
    );
  }
}
