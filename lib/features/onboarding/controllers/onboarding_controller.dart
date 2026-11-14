import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';

/// First-launch introduction: what the app does, then camera and location
/// permission with the reason for each.
class OnboardingController extends GetxController with WidgetsBindingObserver {
  OnboardingController(this._permissions, this._storage);

  static const int pageCount = 3;

  final PermissionService _permissions;
  final StorageService _storage;

  final RxInt page = 0.obs;
  final Rxn<PermissionAccess> camera = Rxn<PermissionAccess>();
  final Rxn<PermissionAccess> location = Rxn<PermissionAccess>();

  /// Drives the page view; owned here so buttons can move between pages.
  final PageController pages = PageController();

  bool get isLastPage => page.value == pageCount - 1;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refreshStatus());
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    pages.dispose();
    super.onClose();
  }

  /// Coming back from system settings may have changed a permission.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_permissions.isRequesting) {
      unawaited(refreshStatus());
    }
  }

  Future<void> refreshStatus() async {
    try {
      camera.value = await _permissions.cameraStatus();
      location.value = await _permissions.locationStatus();
    } catch (_) {
      // Unknown status just shows the Allow buttons.
    }
  }

  Future<void> requestCamera() async {
    if (camera.value == PermissionAccess.blocked) {
      await _permissions.openSettings();
      return;
    }
    camera.value = await _permissions.requestCamera();
  }

  Future<void> requestLocation() async {
    if (location.value == PermissionAccess.blocked) {
      await _permissions.openSettings();
      return;
    }
    location.value = await _permissions.requestLocation();
  }

  void onPageChanged(int index) => page.value = index;

  Future<void> next() async {
    if (isLastPage) return finish();
    await pages.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// Never shown again after this, whether finished or skipped.
  Future<void> finish({bool openCamera = false}) async {
    await _storage.write(StorageKeys.onboardingDone, true);
    // Not awaited: the future only completes when home is closed, so the
    // camera would never open.
    unawaited(Get.offAllNamed<void>(AppRoutes.home));
    if (openCamera) unawaited(Get.toNamed<void>(AppRoutes.camera));
  }
}
