import 'package:get/get.dart';
import 'package:gps_camera/features/projects/controllers/projects_controller.dart';

class ProjectsBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(ProjectsController.new);
}
