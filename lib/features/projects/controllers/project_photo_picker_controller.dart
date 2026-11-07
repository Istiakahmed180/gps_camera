import 'dart:async';

import 'package:get/get.dart';
import 'package:gps_camera/features/gallery/models/gallery_filter.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/projects/models/photo_refs.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

enum PhotoPickerStatus { loading, ready, error }

/// Chooses original photos to add to a project. Watermarked copies are not
/// offered: they follow their original automatically.
class ProjectPhotoPickerController extends GetxController {
  ProjectPhotoPickerController({
    required this.projectId,
    required this._repo,
    required this._gallery,
  });

  final String projectId;
  final ProjectRepository _repo;
  final GalleryService _gallery;

  final Rx<PhotoPickerStatus> status = PhotoPickerStatus.loading.obs;
  final Rx<GalleryIndex> index = GalleryIndex.empty.obs;
  final RxList<GalleryPhoto> originals = <GalleryPhoto>[].obs;
  final RxMap<String, ProjectRef> assignments = <String, ProjectRef>{}.obs;
  final RxSet<String> selected = <String>{}.obs;
  final RxBool isSaving = false.obs;
  final RxnString error = RxnString();

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final scanned = await _gallery.scan();
      index.value = scanned;
      originals.assignAll(
        scanned.view(GalleryFilter.originals, GallerySort.newestFirst),
      );
      assignments.assignAll(await _repo.assignments());
      status.value = PhotoPickerStatus.ready;
    } catch (_) {
      status.value = PhotoPickerStatus.error;
    }
  }

  ProjectRef? projectOf(GalleryPhoto photo) =>
      assignments[PhotoRefs.original(photo.fileName)];

  bool isInThisProject(GalleryPhoto photo) => projectOf(photo)?.id == projectId;

  bool isSelected(GalleryPhoto photo) =>
      selected.contains(PhotoRefs.original(photo.fileName));

  void toggle(GalleryPhoto photo) {
    if (isInThisProject(photo)) return;
    final ref = PhotoRefs.original(photo.fileName);
    selected.contains(ref) ? selected.remove(ref) : selected.add(ref);
  }

  /// Selected photos currently in a different project; they will move.
  int get movingCount => selected
      .where(
        (ref) => assignments[ref] != null && assignments[ref]!.id != projectId,
      )
      .length;

  /// Saves and closes with the number of photos added.
  Future<void> save() async {
    if (selected.isEmpty || isSaving.value) return;
    isSaving.value = true;
    error.value = null;
    try {
      await _repo.assignAll(selected, projectId);
      Get.back(result: selected.length);
    } on ProjectValidationException catch (e) {
      error.value = e.message;
    } catch (_) {
      error.value = 'Photos could not be added. Try again.';
    } finally {
      isSaving.value = false;
    }
  }
}
