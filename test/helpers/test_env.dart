import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/services/permission_service.dart';

/// Points path_provider at a temporary directory and returns it.
Future<Directory> mockPathProvider() async {
  final dir = await Directory.systemTemp.createTemp('gps_camera_test');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => dir.path,
      );
  return dir;
}

class FakePermissionService extends PermissionService {
  FakePermissionService({
    this.status = CameraPermission.denied,
    CameraPermission? requestResult,
  }) : requestResult = requestResult ?? status;

  CameraPermission status;
  CameraPermission requestResult;
  int requestCount = 0;
  int settingsCount = 0;

  @override
  Future<CameraPermission> cameraStatus() async => status;

  @override
  Future<CameraPermission> requestCamera() async {
    requestCount++;
    status = requestResult;
    return requestResult;
  }

  @override
  Future<bool> openSettings() async {
    settingsCount++;
    return true;
  }
}
