import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

enum CameraPermission { granted, denied, blocked }

/// Thin wrapper over permission_handler so controllers stay testable.
class PermissionService extends GetxService {
  Future<CameraPermission> cameraStatus() async {
    return _map(await Permission.camera.status);
  }

  Future<CameraPermission> requestCamera() async {
    final result = _map(await Permission.camera.request());
    if (result == CameraPermission.denied && await _androidWillNotPrompt()) {
      return CameraPermission.blocked;
    }
    return result;
  }

  /// After a denied request, Android stops showing the dialog once the
  /// rationale flag is false. permission_handler only reports that as
  /// permanently denied within the same process, so check it explicitly.
  Future<bool> _androidWillNotPrompt() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    return !await Permission.camera.shouldShowRequestRationale;
  }

  Future<bool> openSettings() => openAppSettings();

  CameraPermission _map(PermissionStatus status) {
    return switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited => CameraPermission.granted,
      PermissionStatus.permanentlyDenied ||
      PermissionStatus.restricted => CameraPermission.blocked,
      _ => CameraPermission.denied,
    };
  }
}
