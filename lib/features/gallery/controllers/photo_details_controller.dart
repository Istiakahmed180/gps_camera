import 'dart:async';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_scanner.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';

/// One photo's details screen. Registered with the photo's id as tag so
/// several details screens can be stacked (copy → its original).
class PhotoDetailsController extends GetxController {
  PhotoDetailsController({
    required this.photo,
    required this._gallery,
    required this._service,
    required this._share,
  });

  final GalleryPhoto photo;
  final GalleryController _gallery;
  final GalleryService _service;
  final ShareService _share;

  final Rxn<ImageDimensions> dimensions = Rxn<ImageDimensions>();
  final RxBool isBusy = false.obs;

  /// Watermarked copies of this original, kept current as the gallery
  /// rescans.
  List<GalleryPhoto> get variants => _gallery.index.value.variantsOf(photo);

  /// The original of this watermarked copy, or null if it was deleted.
  GalleryPhoto? get source => _gallery.index.value.sourceOf(photo);

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

  /// Only originals can be watermarked; copies never become a source.
  Future<void> openWatermarkEditor() async {
    if (!photo.isOriginal) return;
    await Get.toNamed<void>(AppRoutes.watermark, arguments: photo.path);
    await _gallery.reload();
  }

  Future<void> openRelated(GalleryPhoto other) => _gallery.openPhoto(other);

  DeletePlan planDelete() => _service.planDelete(photo, _gallery.index.value);

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
      await _gallery.reload();
      return result;
    } finally {
      isBusy.value = false;
    }
  }
}
