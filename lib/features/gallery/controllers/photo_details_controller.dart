import 'dart:async';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';
import 'package:gps_camera/features/video/services/video_stamp_service.dart';
import 'package:gps_camera/features/export/services/gallery_export_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
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

  /// The note as currently saved. A copy shows the note it was made with.
  late final RxnString note = RxnString(photo.metadata?.note);

  /// Only an original with metadata keeps an editable note.
  bool get canEditNote => photo.isOriginal && photo.metadata != null;

  /// Saves [value] as the note; returns an error message or null.
  Future<String?> saveNote(String? value) async {
    if (!canEditNote) return 'This photo has no editable note.'.tr;
    try {
      note.value = await _service.updateNote(photo, value);
      unawaited(_library.reload());
      return null;
    } catch (_) {
      return 'The note could not be saved.'.tr;
    }
  }

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
      return ('The original of this copy was deleted, so its project '
              'cannot be changed.')
          .tr;
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
      return 'The project could not be updated. Try again.'.tr;
    } finally {
      isBusy.value = false;
    }
  }

  /// Only originals can be watermarked; copies never become a source.
  /// A video gets a new stamped copy with the current watermark settings.
  Future<void> openWatermarkEditor() async {
    if (!photo.isOriginal) return;
    if (photo.isVideo) {
      await stampVideo();
      return;
    }
    await Get.toNamed<void>(AppRoutes.watermark, arguments: photo.path);
    await _library.reload();
  }

  /// This video is being stamped (after capture, here or by recovery), so
  /// it must not be deleted yet. Reactive inside Obx.
  bool get isBeingStamped =>
      photo.isVideo &&
      Get.isRegistered<VideoStampService>() &&
      Get.find<VideoStampService>().busyWith.value == photo.path;

  /// 0 to 1 while this video is being stamped.
  final Rxn<double> stampProgress = Rxn<double>();

  /// Message about the last stamp attempt, for a snack bar.
  final Rxn<(String, bool)> stampResult = Rxn<(String, bool)>();

  /// Makes a stamped copy of this video with the current settings.
  Future<void> stampVideo() async {
    final metadata = photo.metadata;
    if (!photo.isVideo || metadata == null || isBusy.value) return;
    final stamper = Get.find<VideoStampService>();
    isBusy.value = true;
    final progress = ever<double?>(stamper.progress, (p) {
      stampProgress.value = p;
    });
    try {
      final result = await stamper.stamp(
        original: photo.file,
        metadata: metadata,
        config: WatermarkSettingsStore(Get.find<StorageService>()).load(),
      );
      if (Get.isRegistered<GalleryExportService>()) {
        await Get.find<GalleryExportService>().exportEdited(
          result.output,
          takenAt: metadata.capturedAt,
        );
      }
      stampResult.value = ('Stamped video saved'.tr, false);
      await _library.reload();
    } on WatermarkException catch (e) {
      stampResult.value = (
        'Stamped video not saved: @error'.trParams({'error': e.message}),
        true,
      );
    } finally {
      progress.dispose();
      stampProgress.value = null;
      isBusy.value = false;
    }
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
