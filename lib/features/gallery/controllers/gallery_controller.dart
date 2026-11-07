import 'dart:async';

import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/features/gallery/models/gallery_filter.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/models/photo_library.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/projects/models/photo_refs.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

enum GalleryStatus { loading, ready, error }

class GalleryController extends GetxController implements PhotoLibrary {
  GalleryController(this._service, this._projects);

  final GalleryService _service;
  final ProjectRepository _projects;

  final Rx<GalleryStatus> status = GalleryStatus.loading.obs;
  @override
  final Rx<GalleryIndex> index = GalleryIndex.empty.obs;
  final Rx<GalleryFilter> filter = GalleryFilter.all.obs;
  final Rx<GallerySort> sort = GallerySort.newestFirst.obs;
  final Rx<ProjectFilter> projectFilter = ProjectFilter.any.obs;
  final RxBool isRefreshing = false.obs;

  /// Original photo ref → project. Empty if the database is unavailable,
  /// which never stops the gallery from showing photos.
  final RxMap<String, ProjectRef> assignments = <String, ProjectRef>{}.obs;

  /// Projects offered in the project filter.
  final RxList<Project> projectOptions = <Project>[].obs;

  Future<void>? _scan;
  bool _rescanRequested = false;

  List<GalleryPhoto> get visible {
    final byProject = projectFilter.value;
    final photos = index.value.view(filter.value, sort.value);
    if (!byProject.isActive) return photos;
    return photos.where((p) => byProject.matches(projectOf(p))).toList();
  }

  @override
  ProjectRef? projectOf(GalleryPhoto photo) {
    final key = PhotoRefs.assignmentKey(photo);
    return key == null ? null : assignments[key];
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(reload());
  }

  /// Rescans storage. Calls during a scan are merged into one follow-up
  /// scan, so files are never scanned twice at once and changes made
  /// mid-scan are still picked up.
  @override
  Future<void> reload() {
    if (_scan != null) {
      _rescanRequested = true;
      return _scan!;
    }
    return _scan = _runScans().whenComplete(() => _scan = null);
  }

  Future<void> _runScans() async {
    do {
      _rescanRequested = false;
      await _scanOnce();
    } while (_rescanRequested);
  }

  Future<void> _scanOnce() async {
    final firstLoad = status.value != GalleryStatus.ready;
    if (!firstLoad) isRefreshing.value = true;
    final startedAt = DateTime.now();
    try {
      final scanned = await _service.scan();
      index.value = scanned;
      status.value = GalleryStatus.ready;
      await _repairAssignments(scanned, startedAt);
      await reloadAssignments();
    } catch (_) {
      if (firstLoad) status.value = GalleryStatus.error;
    } finally {
      isRefreshing.value = false;
    }
  }

  /// Drops database rows for files that no longer exist. Only after a
  /// complete scan, so a storage error can never wipe assignments.
  Future<void> _repairAssignments(
    GalleryIndex scanned,
    DateTime startedAt,
  ) async {
    if (!scanned.complete) return;
    try {
      await _projects.reconcile(
        existingRefs: scanned.fileRefs,
        scannedAt: startedAt,
      );
    } catch (_) {
      // The next complete scan retries.
    }
  }

  @override
  Future<void> reloadAssignments() async {
    try {
      assignments.assignAll(await _projects.assignments());
      projectOptions.assignAll(await _projects.activeProjects());
    } catch (_) {
      assignments.clear();
      projectOptions.clear();
    }
    final selected = projectFilter.value.projectId;
    if (selected != null && !_knownProject(selected)) {
      projectFilter.value = ProjectFilter.any;
    }
  }

  /// Projects for the filter menu: active ones plus any archived project
  /// that still has photos here.
  List<ProjectRef> get filterProjects {
    final refs = <String, ProjectRef>{
      for (final p in projectOptions) p.id: p.ref,
      for (final ref in assignments.values) ref.id: ref,
    };
    return refs.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  bool _knownProject(String id) => filterProjects.any((p) => p.id == id);

  void setFilter(GalleryFilter value) => filter.value = value;

  void setSort(GallerySort value) => sort.value = value;

  void setProjectFilter(ProjectFilter value) => projectFilter.value = value;

  @override
  Future<void> openPhoto(GalleryPhoto photo) async {
    await Get.toNamed<void>(
      AppRoutes.photoDetails,
      arguments: PhotoDetailsArgs(photo: photo, library: this),
      preventDuplicates: false,
    );
    await reload();
  }

  Future<void> openCamera() async {
    await Get.toNamed<void>(AppRoutes.camera);
    await reload();
  }
}
