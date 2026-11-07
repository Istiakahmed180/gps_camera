import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/features/camera/bindings/camera_binding.dart';
import 'package:gps_camera/features/camera/views/camera_view.dart';
import 'package:gps_camera/features/gallery/bindings/gallery_binding.dart';
import 'package:gps_camera/features/gallery/views/gallery_view.dart';
import 'package:gps_camera/features/home/bindings/home_binding.dart';
import 'package:gps_camera/features/home/views/home_view.dart';
import 'package:gps_camera/features/projects/bindings/projects_binding.dart';
import 'package:gps_camera/features/projects/views/projects_view.dart';
import 'package:gps_camera/features/settings/bindings/settings_binding.dart';
import 'package:gps_camera/features/settings/views/settings_view.dart';

abstract final class AppPages {
  static const String initial = AppRoutes.home;

  static final List<GetPage<dynamic>> pages = [
    GetPage<dynamic>(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.camera,
      page: () => const CameraView(),
      binding: CameraBinding(),
      transition: Transition.downToUp,
    ),
    GetPage<dynamic>(
      name: AppRoutes.gallery,
      page: () => const GalleryView(),
      binding: GalleryBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.projects,
      page: () => const ProjectsView(),
      binding: ProjectsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settings,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
    ),
  ];
}
