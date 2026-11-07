import 'dart:async';

import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/features/gallery/models/gallery_filter.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';

enum GalleryStatus { loading, ready, error }

class GalleryController extends GetxController {
  GalleryController(this._service);

  final GalleryService _service;

  final Rx<GalleryStatus> status = GalleryStatus.loading.obs;
  final Rx<GalleryIndex> index = GalleryIndex.empty.obs;
  final Rx<GalleryFilter> filter = GalleryFilter.all.obs;
  final Rx<GallerySort> sort = GallerySort.newestFirst.obs;
  final RxBool isRefreshing = false.obs;

  Future<void>? _scan;
  bool _rescanRequested = false;

  List<GalleryPhoto> get visible => index.value.view(filter.value, sort.value);

  @override
  void onInit() {
    super.onInit();
    unawaited(reload());
  }

  /// Rescans storage. Calls during a scan are merged into one follow-up
  /// scan, so files are never scanned twice at once and changes made
  /// mid-scan are still picked up.
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
    try {
      index.value = await _service.scan();
      status.value = GalleryStatus.ready;
    } catch (_) {
      if (firstLoad) status.value = GalleryStatus.error;
    } finally {
      isRefreshing.value = false;
    }
  }

  void setFilter(GalleryFilter value) => filter.value = value;

  void setSort(GallerySort value) => sort.value = value;

  Future<void> openPhoto(GalleryPhoto photo) async {
    await Get.toNamed<void>(
      AppRoutes.photoDetails,
      arguments: photo,
      preventDuplicates: false,
    );
    await reload();
  }

  Future<void> openCamera() async {
    await Get.toNamed<void>(AppRoutes.camera);
    await reload();
  }
}
