import 'dart:async';

import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/projects/models/photo_refs.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

enum ProjectsStatus { loading, ready, error }

/// The project list: active or archived, with search.
class ProjectsController extends GetxController {
  ProjectsController(this._repo, this._storage);

  final ProjectRepository _repo;
  final PhotoStorageService _storage;

  final Rx<ProjectsStatus> status = ProjectsStatus.loading.obs;
  final RxList<ProjectSummary> items = <ProjectSummary>[].obs;
  final RxBool showArchived = false.obs;
  final RxString query = ''.obs;
  final RxnString rootPath = RxnString();

  int _loadToken = 0;

  @override
  void onInit() {
    super.onInit();
    debounce<String>(
      query,
      (_) => load(),
      time: const Duration(milliseconds: 250),
    );
    ever<bool>(showArchived, (_) => load());
    unawaited(_resolveRoot());
    unawaited(load());
  }

  Future<void> _resolveRoot() async {
    try {
      rootPath.value = (await _storage.rootDirectory()).path;
    } catch (_) {
      rootPath.value = null;
    }
  }

  /// Ignores results from older loads, so fast typing never shows stale
  /// search results.
  Future<void> load() async {
    final token = ++_loadToken;
    try {
      final result = await _repo.summaries(
        archived: showArchived.value,
        query: query.value,
      );
      if (token != _loadToken) return;
      items.assignAll(result);
      status.value = ProjectsStatus.ready;
    } catch (_) {
      if (token == _loadToken) status.value = ProjectsStatus.error;
    }
  }

  String? coverPath(ProjectSummary summary) {
    final root = rootPath.value;
    final ref = summary.displayCoverRef;
    return root == null || ref == null ? null : PhotoRefs.resolve(root, ref);
  }

  Future<void> create() async {
    // GetX routes are typed dynamic; a typed toNamed would fail its cast.
    final created = await Get.toNamed<dynamic>(AppRoutes.projectEdit);
    if (created is Project) {
      showArchived.value = false;
      await load();
      await open(created.id);
    }
  }

  Future<void> open(String projectId) async {
    await Get.toNamed<void>(AppRoutes.projectDetails, arguments: projectId);
    await load();
  }
}
