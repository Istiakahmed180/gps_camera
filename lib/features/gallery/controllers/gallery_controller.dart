import 'dart:async';

import 'package:get/get.dart';
import 'package:gps_camera/core/settings/display_format.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/features/gallery/models/gallery_filter.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/models/photo_library.dart';
import 'package:gps_camera/features/gallery/models/photo_search.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/projects/models/photo_refs.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/reports/services/report_entry_builder.dart';

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

  /// Text typed in the search field; empty shows everything.
  final RxString query = ''.obs;

  /// Whether the app bar shows the search field.
  final RxBool searching = false.obs;

  /// Original photo ref → project. Empty if the database is unavailable,
  /// which never stops the gallery from showing photos.
  final RxMap<String, ProjectRef> assignments = <String, ProjectRef>{}.obs;

  /// Projects offered in the project filter.
  final RxList<Project> projectOptions = <Project>[].obs;

  /// Multi-select for reports. Selecting changes no photo or project data.
  final RxBool selecting = false.obs;
  final RxSet<String> selectedIds = <String>{}.obs;

  Future<void>? _scan;
  bool _rescanRequested = false;

  List<GalleryPhoto> get visible {
    final byProject = projectFilter.value;
    final words = PhotoSearch.words(query.value);
    final photos = index.value.view(filter.value, sort.value);
    if (!byProject.isActive && words.isEmpty) return photos;
    return photos.where((p) {
      final project = projectOf(p);
      if (byProject.isActive && !byProject.matches(project)) return false;
      return PhotoSearch.matches(p, words, projectName: project?.name);
    }).toList();
  }

  void setQuery(String value) => query.value = value;

  void startSearch() => searching.value = true;

  void stopSearch() {
    searching.value = false;
    query.value = '';
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
      selectedIds.removeWhere((id) => scanned.byId(id) == null);
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

  void startSelection([GalleryPhoto? first]) {
    selecting.value = true;
    if (first != null) selectedIds.add(first.id);
  }

  void toggleSelection(GalleryPhoto photo) {
    selectedIds.contains(photo.id)
        ? selectedIds.remove(photo.id)
        : selectedIds.add(photo.id);
  }

  void selectAllVisible() => selectedIds.addAll(visible.map((p) => p.id));

  void cancelSelection() {
    selecting.value = false;
    selectedIds.clear();
  }

  List<GalleryPhoto> get selectedPhotos => [
    for (final id in selectedIds) ?index.value.byId(id),
  ];

  /// Selected originals that have watermarked copies not selected too.
  int get selectedWithCopies => selectedPhotos
      .where(
        (p) =>
            p.isOriginal &&
            index.value.variantsOf(p).any((v) => !selectedIds.contains(v.id)),
      )
      .length;

  final RxBool isBusy = false.obs;

  /// Deletes the selected photos (and their copies when [includeRelated]),
  /// then drops their project assignments. Returns every result so the
  /// view can report exactly what happened.
  Future<List<DeleteResult>> deleteSelected({
    required bool includeRelated,
  }) async {
    if (isBusy.value) return const [];
    isBusy.value = true;
    try {
      final plans = _service.planDeleteMany(
        selectedPhotos,
        index.value,
        includeRelated: includeRelated,
      );
      final results = <DeleteResult>[];
      for (final plan in plans) {
        results.add(
          await _service.delete(plan, includeRelated: includeRelated),
        );
      }
      try {
        await _projects.forgetPhotos(
          results.expand((r) => r.removedPhotos).map(PhotoRefs.of),
        );
      } catch (_) {
        // The next scan repairs stale rows.
      }
      cancelSelection();
      await reload();
      return results;
    } finally {
      isBusy.value = false;
    }
  }

  /// Report of the selected photos, one entry per capture, or null when
  /// nothing is selected.
  ReportJob? selectionReport({DateTime? now}) {
    final entries = ReportEntryBuilder.forSelection(
      selectedPhotos,
      index.value,
      projectOf: projectOf,
    );
    if (entries.isEmpty) return null;
    return ReportJob(
      format: DisplayFormat.current,
      type: ReportType.selection,
      title: 'Selected photos report'.tr,
      generatedAt: now ?? DateTime.now(),
      entries: entries,
    );
  }

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

  Future<void> openMap() async {
    await Get.toNamed<void>(AppRoutes.photoMap);
  }

  Future<void> openCamera() async {
    await Get.toNamed<void>(AppRoutes.camera);
    await reload();
  }
}
