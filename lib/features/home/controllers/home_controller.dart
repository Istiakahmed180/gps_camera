import 'dart:async';

import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/home/controllers/current_place_controller.dart';
import 'package:gps_camera/features/projects/controllers/projects_controller.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';
import 'package:gps_camera/features/reports/controllers/reports_controller.dart';

/// The tabs along the bottom of the main screen.
enum HomeTab { home, gallery, projects, reports }

/// The main screen: the tab shown, and the dashboard's figures, which come
/// from the gallery, projects and reports tabs so every tab agrees.
class HomeController extends GetxController {
  HomeController({
    required this.gallery,
    required this.projects,
    required this.reports,
    required this._repository,
    required this.here,
  });

  /// Where the phone is now, for the camera card.
  final CurrentPlaceController here;

  /// The main screen is on top and the app is in the foreground.
  bool _visible = true;

  final ProjectRepository _repository;

  final GalleryController gallery;
  final ProjectsController projects;
  final ReportsController reports;

  final Rx<HomeTab> tab = HomeTab.home.obs;

  /// Active projects, most recently changed first, whatever the projects
  /// tab is showing.
  final RxList<ProjectSummary> activeProjects = <ProjectSummary>[].obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadProjects());
    _syncLocation();
  }

  /// Called when the main screen is covered or uncovered, or the app goes
  /// to the background or comes back.
  void setVisible(bool visible) {
    _visible = visible;
    _syncLocation();
  }

  /// The location is looked up only while the dashboard can be seen.
  void _syncLocation() {
    if (_visible && tab.value == HomeTab.home) {
      here.resume();
    } else {
      here.pause();
    }
  }

  Future<void> _loadProjects() async {
    try {
      activeProjects.assignAll(await _repository.summaries(archived: false));
    } catch (_) {
      // Kept as it was; the projects tab reports errors.
    }
  }

  /// How many recent captures the dashboard shows.
  static const int recentCount = 12;

  /// How many projects the dashboard lists.
  static const int projectCount = 3;

  void select(HomeTab value) {
    if (tab.value == value) return;
    tab.value = value;
    _syncLocation();
    unawaited(refreshTab(value));
  }

  /// Rereads what [value] shows, e.g. after returning from the camera.
  Future<void> refreshTab(HomeTab value) => switch (value) {
    HomeTab.home => Future.wait([
      gallery.reload(),
      _loadProjects(),
      reports.load(),
      here.locate(),
    ]),
    HomeTab.gallery => gallery.reload(),
    HomeTab.projects => projects.load(),
    HomeTab.reports => reports.load(),
  };

  Future<void> refreshCurrent() => refreshTab(tab.value);

  /// Originals, newest first: what the user captured.
  List<GalleryPhoto> get captures {
    final originals =
        gallery.index.value.photos
            .where((p) => p.isOriginal && p.issue == null)
            .toList()
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return originals;
  }

  int get photoCount => captures.where((p) => !p.isVideo).length;

  int get videoCount => captures.where((p) => p.isVideo).length;

  int get reportCount => reports.reports.length;

  Future<void> openCamera() async {
    await Get.toNamed<void>(AppRoutes.camera);
    await refreshCurrent();
  }

  Future<void> openSettings() async {
    await Get.toNamed<void>(AppRoutes.settings);
    await refreshCurrent();
  }

  Future<void> openPhoto(GalleryPhoto photo) => gallery.openPhoto(photo);

  Future<void> openProject(ProjectSummary summary) async {
    await projects.open(summary.project.id);
    await refreshCurrent();
  }

  Future<void> createProject() async {
    await projects.create();
    await refreshCurrent();
  }
}
