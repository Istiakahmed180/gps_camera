import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionAccess { granted, denied, blocked }

/// Thin wrapper over permission_handler so controllers stay testable.
///
/// Requests run one at a time, and [isRequesting] stays true while a system
/// dialog is showing so lifecycle observers can ignore the inactive/resumed
/// events the dialog causes.
class PermissionService extends GetxService {
  Future<void> _pending = Future<void>.value();
  int _activeRequests = 0;

  bool get isRequesting => _activeRequests > 0;

  Future<PermissionAccess> cameraStatus() => _status(Permission.camera);

  Future<PermissionAccess> requestCamera() => _request(Permission.camera);

  /// For sound in videos. Videos are recorded silently without it.
  Future<PermissionAccess> microphoneStatus() => _status(Permission.microphone);

  Future<PermissionAccess> requestMicrophone() =>
      _request(Permission.microphone);

  /// Foreground ("while in use") location only.
  Future<PermissionAccess> locationStatus() =>
      _status(Permission.locationWhenInUse);

  Future<PermissionAccess> requestLocation() =>
      _request(Permission.locationWhenInUse);

  Future<bool> openSettings() => openAppSettings();

  Future<PermissionAccess> _status(Permission permission) async {
    return _map(await permission.status);
  }

  Future<PermissionAccess> _request(Permission permission) {
    _activeRequests++;
    final result = _pending.then((_) async {
      final access = _map(await permission.request());
      if (access == PermissionAccess.denied &&
          await _androidWillNotPrompt(permission)) {
        return PermissionAccess.blocked;
      }
      return access;
    });
    _pending = result.then<void>((_) {}, onError: (Object _) {});
    return result.whenComplete(() => _activeRequests--);
  }

  /// After a denied request, Android stops showing the dialog once the
  /// rationale flag is false. permission_handler only reports that as
  /// permanently denied within the same process, so check it explicitly.
  Future<bool> _androidWillNotPrompt(Permission permission) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    return !await permission.shouldShowRequestRationale;
  }

  PermissionAccess _map(PermissionStatus status) {
    return switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited => PermissionAccess.granted,
      PermissionStatus.permanentlyDenied ||
      PermissionStatus.restricted => PermissionAccess.blocked,
      _ => PermissionAccess.denied,
    };
  }
}
