import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/projects/models/photo_refs.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

/// Create (when [existing] is null) or edit a project.
class ProjectEditController extends GetxController {
  ProjectEditController({
    required this.existing,
    required this._repo,
    required this._gallery,
    required this._storage,
  });

  final Project? existing;
  final ProjectRepository _repo;
  final GalleryService _gallery;
  final PhotoStorageService _storage;

  late final TextEditingController name;
  late final TextEditingController description;
  final RxnString nameError = RxnString();
  final RxnString formError = RxnString();
  final RxBool isSaving = false.obs;

  /// Photos in this project that can be the cover.
  final RxList<GalleryPhoto> coverOptions = <GalleryPhoto>[].obs;
  final RxnString coverRef = RxnString();

  bool get isNew => existing == null;

  @override
  void onInit() {
    super.onInit();
    name = TextEditingController(text: existing?.name ?? '');
    description = TextEditingController(text: existing?.description ?? '');
    coverRef.value = existing?.coverPhotoRef;
    if (!isNew) unawaited(_loadCoverOptions());
  }

  @override
  void onClose() {
    name.dispose();
    description.dispose();
    super.onClose();
  }

  Future<void> _loadCoverOptions() async {
    try {
      final refs = await _repo.photoRefsOf(existing!.id);
      final index = await _gallery.scan();
      coverOptions.assignAll(
        index.photos.where((p) => refs.contains(PhotoRefs.assignmentKey(p))),
      );
    } catch (_) {
      coverOptions.clear();
    }
  }

  Future<String?> rootPath() async {
    try {
      return (await _storage.rootDirectory()).path;
    } catch (_) {
      return null;
    }
  }

  void selectCover(GalleryPhoto? photo) =>
      coverRef.value = photo == null ? null : PhotoRefs.of(photo);

  void clearNameError() {
    if (nameError.value != null) nameError.value = null;
  }

  /// Validates and saves. Closes the screen with the saved project.
  Future<void> save() async {
    if (isSaving.value) return;
    if (name.text.trim().isEmpty) {
      nameError.value = 'Enter a project name.';
      return;
    }
    isSaving.value = true;
    formError.value = null;
    try {
      final project = isNew
          ? await _repo.create(name: name.text, description: description.text)
          : await _repo.update(
              existing!.id,
              name: name.text,
              description: description.text,
              coverPhotoRef: coverRef.value,
            );
      Get.back(result: project);
    } on ProjectValidationException catch (e) {
      if (e.message.contains('description')) {
        formError.value = e.message;
      } else {
        nameError.value = e.message;
      }
    } catch (_) {
      formError.value = 'The project could not be saved. Try again.';
    } finally {
      isSaving.value = false;
    }
  }
}
