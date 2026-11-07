import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/projects/controllers/projects_controller.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

class ProjectsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => ProjectsController(
        Get.find<ProjectRepository>(),
        Get.find<PhotoStorageService>(),
      ),
    );
  }
}
