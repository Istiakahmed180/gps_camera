import 'package:get/get.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/features/home/controllers/current_place_controller.dart';
import 'package:gps_camera/features/location/services/location_service.dart';
import 'package:gps_camera/features/location/services/place_service.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/home/controllers/home_controller.dart';
import 'package:gps_camera/features/projects/controllers/projects_controller.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';
import 'package:gps_camera/features/reports/controllers/reports_controller.dart';
import 'package:gps_camera/features/reports/services/report_service.dart';

/// The main screen and its tabs. The tab controllers are created here, under
/// the main route, so they live as long as it does: a gallery or reports
/// screen opened on top (from the camera, say) reuses them and leaves them
/// in place when it closes.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    final repository = Get.find<ProjectRepository>();
    final gallery = Get.isRegistered<GalleryController>()
        ? Get.find<GalleryController>()
        : Get.put(GalleryController(Get.find<GalleryService>(), repository));
    final projects = Get.isRegistered<ProjectsController>()
        ? Get.find<ProjectsController>()
        : Get.put(
            ProjectsController(repository, Get.find<PhotoStorageService>()),
          );
    final reports = Get.isRegistered<ReportsController>()
        ? Get.find<ReportsController>()
        : Get.put(ReportsController(Get.find<ReportService>()));
    final here = Get.put(
      CurrentPlaceController(
        Get.isRegistered<LocationService>()
            ? Get.find<LocationService>()
            : LocationService(Get.find<PermissionService>()),
        PlaceService(),
      ),
    );
    Get.put(
      HomeController(
        gallery: gallery,
        projects: projects,
        reports: reports,
        repository: repository,
        here: here,
      ),
    );
  }
}
