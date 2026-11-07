import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/controllers/capture_controller.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/camera/models/camera_status.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePermissionService permissions;

  CaptureController build({
    Future<List<CameraDescription>> Function()? loader,
  }) {
    return Get.put(
      CaptureController(
        permissions,
        CaptureSaver(PhotoStorageService()),
        LocationController(FakeLocationService(), permissions),
        cameraLoader: loader ?? () async => const [],
      ),
    );
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  tearDown(Get.reset);

  test('requests permission on open and shows denied state', () async {
    permissions = FakePermissionService();
    final controller = build();
    await settle();

    expect(permissions.requestCount, 1);
    expect(controller.status.value, CameraStatus.permissionDenied);
    expect(controller.canCapture, isFalse);
  });

  test('blocked permission does not prompt and opens settings', () async {
    permissions = FakePermissionService(status: PermissionAccess.blocked);
    final controller = build();
    await settle();

    expect(permissions.requestCount, 0);
    expect(controller.status.value, CameraStatus.permissionBlocked);

    await controller.openSettings();
    expect(permissions.settingsCount, 1);
  });

  test('stays blocked when Android later reports plain denied', () async {
    permissions = FakePermissionService(status: PermissionAccess.blocked);
    final controller = build();
    await settle();

    permissions.status = PermissionAccess.denied;
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();

    expect(controller.status.value, CameraStatus.permissionBlocked);
  });

  test('no cameras gives a readable error instead of crashing', () async {
    permissions = FakePermissionService(status: PermissionAccess.granted);
    final controller = build();
    await settle();

    expect(controller.status.value, CameraStatus.error);
    expect(controller.errorMessage.value, contains('No camera'));
  });

  test('camera loader failure is reported as unavailable', () async {
    permissions = FakePermissionService(
      requestResult: PermissionAccess.granted,
    );
    final controller = build(
      loader: () async => throw CameraException('Boom', 'driver failure'),
    );
    await settle();

    expect(controller.status.value, CameraStatus.error);
    expect(controller.errorMessage.value, contains('driver failure'));
  });

  test('capture is ignored when the camera is not ready', () async {
    permissions = FakePermissionService();
    final controller = build();
    await settle();

    await controller.capture();
    expect(controller.isCapturing.value, isFalse);
    expect(controller.lastPhotoPath.value, isNull);
  });
}
