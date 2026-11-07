import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/services/location_service.dart';

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

LocationFix testFix({
  double latitude = 37.4219983,
  double longitude = -122.084,
  double accuracy = 4.2,
  DateTime? timestamp,
  double? altitude = 12.5,
}) {
  return LocationFix(
    latitude: latitude,
    longitude: longitude,
    accuracy: accuracy,
    timestamp: timestamp ?? DateTime.now().toUtc(),
    altitude: altitude,
    altitudeReference: altitude == null
        ? null
        : AltitudeReference.wgs84Ellipsoid,
  );
}

class FakePermissionService extends PermissionService {
  FakePermissionService({
    this.status = PermissionAccess.denied,
    PermissionAccess? requestResult,
    this.location = PermissionAccess.denied,
  }) : requestResult = requestResult ?? status;

  PermissionAccess status;
  PermissionAccess requestResult;
  PermissionAccess location;
  int requestCount = 0;
  int settingsCount = 0;

  @override
  Future<PermissionAccess> cameraStatus() async => status;

  @override
  Future<PermissionAccess> requestCamera() async {
    requestCount++;
    status = requestResult;
    return requestResult;
  }

  @override
  Future<PermissionAccess> locationStatus() async => location;

  @override
  Future<PermissionAccess> requestLocation() async => location;

  @override
  Future<bool> openSettings() async {
    settingsCount++;
    return true;
  }
}

/// Scriptable stand-in for GPS hardware.
class FakeLocationService extends LocationService {
  FakeLocationService({
    this.serviceEnabled = true,
    this.permission = PermissionAccess.granted,
    PermissionAccess? requestResult,
  }) : requestResult = requestResult ?? permission,
       super(FakePermissionService());

  bool serviceEnabled;
  PermissionAccess permission;
  PermissionAccess requestResult;
  int requestCount = 0;
  int listenCount = 0;
  int cancelCount = 0;

  final StreamController<bool> serviceChanges =
      StreamController<bool>.broadcast();
  StreamController<LocationFix>? _fixes;

  int get activeSubscriptions => listenCount - cancelCount;

  void emit(LocationFix fix) => _fixes!.add(fix);

  void emitError(Object error) => _fixes!.addError(error);

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Stream<bool> serviceStatusChanges() => serviceChanges.stream;

  @override
  Future<PermissionAccess> checkPermission() async => permission;

  @override
  Future<PermissionAccess> requestPermission() async {
    requestCount++;
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Stream<LocationFix> fixes() {
    final controller = StreamController<LocationFix>(
      onListen: () => listenCount++,
      onCancel: () => cancelCount++,
    );
    _fixes = controller;
    return controller.stream;
  }
}

/// Gallery scan without a background isolate, for widget tests.
class FakeGalleryService extends GalleryService {
  FakeGalleryService([GalleryIndex? index])
    : _index = index ?? GalleryIndex.empty,
      super(PhotoStorageService());

  final GalleryIndex _index;

  @override
  Future<GalleryIndex> scan() async => _index;
}
