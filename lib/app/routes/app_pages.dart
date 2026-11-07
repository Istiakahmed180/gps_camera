import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/features/camera/bindings/camera_binding.dart';
import 'package:gps_camera/features/camera/views/camera_view.dart';
import 'package:gps_camera/features/gallery/bindings/gallery_binding.dart';
import 'package:gps_camera/features/gallery/bindings/photo_details_binding.dart';
import 'package:gps_camera/features/gallery/models/photo_library.dart';
import 'package:gps_camera/features/gallery/views/gallery_view.dart';
import 'package:gps_camera/features/gallery/views/photo_details_view.dart';
import 'package:gps_camera/features/home/bindings/home_binding.dart';
import 'package:gps_camera/features/home/views/home_view.dart';
import 'package:gps_camera/features/projects/bindings/project_details_binding.dart';
import 'package:gps_camera/features/projects/bindings/project_edit_binding.dart';
import 'package:gps_camera/features/projects/bindings/project_photo_picker_binding.dart';
import 'package:gps_camera/features/projects/bindings/projects_binding.dart';
import 'package:gps_camera/features/projects/views/project_details_view.dart';
import 'package:gps_camera/features/projects/views/project_edit_view.dart';
import 'package:gps_camera/features/projects/views/project_photo_picker_view.dart';
import 'package:gps_camera/features/projects/views/projects_view.dart';
import 'package:gps_camera/features/reports/bindings/reports_binding.dart';
import 'package:gps_camera/features/reports/views/reports_view.dart';
import 'package:gps_camera/features/settings/bindings/settings_binding.dart';
import 'package:gps_camera/features/settings/views/settings_view.dart';
import 'package:gps_camera/features/watermark/bindings/watermark_binding.dart';
import 'package:gps_camera/features/watermark/views/watermark_editor_view.dart';

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
      name: AppRoutes.photoDetails,
      page: () =>
          PhotoDetailsView(photo: (Get.arguments as PhotoDetailsArgs).photo),
      binding: PhotoDetailsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.projects,
      page: () => const ProjectsView(),
      binding: ProjectsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.projectDetails,
      page: () => const ProjectDetailsView(),
      binding: ProjectDetailsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.projectEdit,
      page: () => const ProjectEditView(),
      binding: ProjectEditBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.projectAddPhotos,
      page: () => const ProjectPhotoPickerView(),
      binding: ProjectPhotoPickerBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.reports,
      page: () => const ReportsView(),
      binding: ReportsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settings,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.watermark,
      page: () => const WatermarkEditorView(),
      binding: WatermarkBinding(),
    ),
  ];
}
