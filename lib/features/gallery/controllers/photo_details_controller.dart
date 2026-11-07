import 'dart:async';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/models/photo_library.dart';
import 'package:gps_camera/features/gallery/services/gallery_scanner.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/projects/models/photo_refs.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

/// One photo's details screen. Registered with the photo's id as tag so
/// several details screens can be stacked (copy → its original).
class PhotoDetailsController extends GetxController {
  PhotoDetailsController({
    required this.photo,
    required this._library,
    required this._service,
    required this._share,
    required this._projects,
  });

  final GalleryPhoto photo;
  final PhotoLibrary _library;
  final GalleryService _service;
  final ShareService _share;
  final ProjectRepository _projects;

  final Rxn<ImageDimensions> dimensions = Rxn<ImageDimensions>();
  final RxBool isBusy = false.obs;

  /// Watermarked copies of this original, kept current as the library
  /// rescans.
  List<GalleryPhoto> get variants => _library.index.value.variantsOf(photo);

  /// The original of this watermarked copy, or null if it was deleted.
  GalleryPhoto? get source => _library.index.value.sourceOf(photo);

  /// This photo's project; a watermarked copy shows its original's.
  ProjectRef? get project => _library.projectOf(photo);

  /// A copy whose original is gone has no assignment to change.
  bool get canChangeProject => photo.isOriginal || source != null;

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadDimensions());
  }

  Future<void> _loadDimensions() async {
    try {
      dimensions.value = await _service.dimensionsOf(photo);
    } catch (_) {
      dimensions.value = null;
    }
  }

  Future<ShareOutcome> share({Rect? origin}) async {
    if (isBusy.value) return ShareOutcome.failed;
    isBusy.value = true;
    try {
      return await _share.shareImage(photo.file, origin: origin);
    } finally {
      isBusy.value = false;
    }
  }

  /// Projects the photo can be moved to.
  Future<List<Project>> assignableProjects() => _projects.activeProjects();

  /// Assigns this photo's original to [target], or removes it from its
  /// project when [target] is null. Returns an error message, or null.
  Future<String?> setProject(Project? target) async {
    final key = PhotoRefs.assignmentKey(photo);
    if (key == null || !canChangeProject) {
      return 'The original of this copy was deleted, so its project '
          'cannot be changed.';
    }
    isBusy.value = true;
    try {
      if (target == null) {
        await _projects.unassign(key);
      } else {
        await _projects.assign(key, target.id);
      }
      await _library.reloadAssignments();
      return null;
    } on ProjectValidationException catch (e) {
      return e.message;
    } catch (_) {
      return 'The project could not be updated. Try again.';
    } finally {
      isBusy.value = false;
    }
  }

  /// Only originals can be watermarked; copies never become a source.
  Future<void> openWatermarkEditor() async {
    if (!photo.isOriginal) return;
    await Get.toNamed<void>(AppRoutes.watermark, arguments: photo.path);
    await _library.reload();
  }

  Future<void> openRelated(GalleryPhoto other) => _library.openPhoto(other);

  DeletePlan planDelete() => _service.planDelete(photo, _library.index.value);

  /// Deletes files, then removes database rows for the photos that are
  /// gone. Projects are never deleted here. If the database update fails,
  /// the next gallery scan repairs it.
  Future<DeleteResult> delete(
    DeletePlan plan, {
    required bool includeRelated,
  }) async {
    isBusy.value = true;
    try {
      final result = await _service.delete(
        plan,
        includeRelated: includeRelated,
      );
      try {
        await _projects.forgetPhotos(result.removedPhotos.map(PhotoRefs.of));
      } catch (_) {
        // Reconciliation on the next scan removes the stale rows.
      }
      await _library.reload();
      return result;
    } finally {
      isBusy.value = false;
    }
  }
}
