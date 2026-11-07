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
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/reports/services/report_entry_builder.dart';

enum ProjectDetailsStatus { loading, ready, missing, error }

/// One project's page. Acts as the [PhotoLibrary] for photo details opened
/// from here, so those screens see only this project's photos.
class ProjectDetailsController extends GetxController implements PhotoLibrary {
  ProjectDetailsController({
    required this.projectId,
    required this._repo,
    required this._gallery,
  });

  final String projectId;
  final ProjectRepository _repo;
  final GalleryService _gallery;

  final Rx<ProjectDetailsStatus> status = ProjectDetailsStatus.loading.obs;
  final Rxn<Project> project = Rxn<Project>();
  @override
  final Rx<GalleryIndex> index = GalleryIndex.empty.obs;
  final Rx<GalleryFilter> filter = GalleryFilter.all.obs;
  final RxBool isBusy = false.obs;

  GalleryIndex _all = GalleryIndex.empty;
  Set<String> _refs = const {};

  int get originalCount => index.value.count(GalleryFilter.originals);

  int get watermarkedCount => index.value.count(GalleryFilter.watermarked);

  List<GalleryPhoto> get visible =>
      index.value.view(filter.value, GallerySort.newestFirst);

  /// Assigned originals whose files are missing from disk.
  int get missingCount => _refs.length - originalCount.clamp(0, _refs.length);

  @override
  void onInit() {
    super.onInit();
    unawaited(reload());
  }

  @override
  ProjectRef? projectOf(GalleryPhoto photo) {
    final current = project.value;
    final key = PhotoRefs.assignmentKey(photo);
    return current != null && key != null && _refs.contains(key)
        ? current.ref
        : null;
  }

  @override
  Future<void> reload() async {
    final startedAt = DateTime.now();
    try {
      final scanned = await _gallery.scan();
      _all = scanned;
      if (scanned.complete) {
        await _repo.reconcile(
          existingRefs: scanned.fileRefs,
          scannedAt: startedAt,
        );
      }
      await reloadAssignments();
    } catch (_) {
      if (project.value == null) status.value = ProjectDetailsStatus.error;
    }
  }

  /// Re-reads the project and its photo list without rescanning files.
  @override
  Future<void> reloadAssignments() async {
    try {
      final found = await _repo.find(projectId);
      if (found == null) {
        status.value = ProjectDetailsStatus.missing;
        return;
      }
      _refs = await _repo.photoRefsOf(projectId);
      project.value = found;
      index.value = GalleryIndex(
        photos: [
          for (final photo in _all.photos)
            if (_refs.contains(PhotoRefs.assignmentKey(photo))) photo,
        ],
        complete: _all.complete,
      );
      status.value = ProjectDetailsStatus.ready;
    } catch (_) {
      if (project.value == null) status.value = ProjectDetailsStatus.error;
    }
  }

  void setFilter(GalleryFilter value) => filter.value = value;

  /// A report of every original in this project (with its watermarked
  /// versions), or null when the project has no photos.
  ReportJob? reportJob({DateTime? now}) {
    final current = project.value;
    final entries = ReportEntryBuilder.forProject(index.value);
    if (current == null || entries.isEmpty) return null;
    return ReportJob(
      type: ReportType.project,
      title: 'Project report: ${current.name}',
      projectId: current.id,
      projectName: current.name,
      projectDescription: current.description,
      generatedAt: now ?? DateTime.now(),
      entries: entries,
    );
  }

  @override
  Future<void> openPhoto(GalleryPhoto photo) async {
    await Get.toNamed<void>(
      AppRoutes.photoDetails,
      arguments: PhotoDetailsArgs(photo: photo, library: this),
      preventDuplicates: false,
    );
    await reload();
  }

  Future<void> edit() async {
    final current = project.value;
    if (current == null) return;
    // GetX routes are typed dynamic; a typed toNamed would fail its cast.
    await Get.toNamed<dynamic>(AppRoutes.projectEdit, arguments: current);
    await reloadAssignments();
  }

  Future<void> addPhotos() async {
    await Get.toNamed<dynamic>(
      AppRoutes.projectAddPhotos,
      arguments: projectId,
    );
    await reload();
  }

  /// Returns an error message, or null on success.
  Future<String?> setArchived(bool archived) => _run(() async {
    archived ? await _repo.archive(projectId) : await _repo.restore(projectId);
    await reloadAssignments();
  });

  /// Deletes the project and its assignments only. Photo files stay.
  Future<String?> delete() => _run(() => _repo.delete(projectId));

  Future<String?> _run(Future<void> Function() action) async {
    if (isBusy.value) return null;
    isBusy.value = true;
    try {
      await action();
      return null;
    } on ProjectValidationException catch (e) {
      return e.message;
    } catch (_) {
      return 'The project could not be updated. Try again.';
    } finally {
      isBusy.value = false;
    }
  }
}
