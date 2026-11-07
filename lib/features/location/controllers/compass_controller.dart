import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/location/models/camera_direction.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/services/compass_service.dart';
import 'package:gps_camera/features/location/services/place_service.dart';

/// The live camera direction on the camera screen. The sensor runs only
/// while this screen is open and the app is in the foreground.
class CompassController extends GetxController with WidgetsBindingObserver {
  CompassController(
    this._service,
    this._location, {
    bool Function()? isFrontCamera,
    this.maxAge = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : _isFrontCamera = isFrontCamera ?? (() => false),
       _clock = clock ?? DateTime.now;

  /// Readings worse than this are not recorded at all.
  static const double unusableAccuracy = 60;

  final CompassService _service;
  final LocationController _location;
  final bool Function() _isFrontCamera;
  final DateTime Function() _clock;

  /// A photo uses the live reading only if it is at most this old.
  final Duration maxAge;

  final RxBool available = false.obs;
  final Rxn<CameraDirection> direction = Rxn<CameraDirection>();

  StreamSubscription<CompassReading>? _readings;
  Worker? _fixWorker;
  double? _declination;
  LocationFix? _declinationAt;
  DateTime? _readAt;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _fixWorker?.dispose();
    unawaited(_readings?.cancel());
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (available.value) _listen();
    } else if (state == AppLifecycleState.paused) {
      unawaited(_readings?.cancel());
      _readings = null;
      direction.value = null;
    }
  }

  Future<void> _start() async {
    available.value = await _service.isAvailable();
    if (!available.value || isClosed) return;
    _fixWorker = ever<LocationFix?>(_location.fix, (fix) {
      if (fix != null) unawaited(_updateDeclination(fix));
    });
    final fix = _location.fix.value;
    if (fix != null) unawaited(_updateDeclination(fix));
    _listen();
  }

  void _listen() {
    if (_readings != null || isClosed) return;
    _readings = _service.readings().listen(
      onReading,
      onError: (Object _) => direction.value = null,
    );
  }

  /// Magnetic north differs from true north by up to tens of degrees; the
  /// difference changes slowly, so it is refreshed every 20 km.
  Future<void> _updateDeclination(LocationFix fix) async {
    final at = _declinationAt;
    if (at != null &&
        PlaceService.distanceMeters(
              at.latitude,
              at.longitude,
              fix.latitude,
              fix.longitude,
            ) <
            20000) {
      return;
    }
    final value = await _service.declination(
      fix.latitude,
      fix.longitude,
      altitude: fix.altitude ?? 0,
    );
    if (value == null) return;
    _declination = value;
    _declinationAt = fix;
  }

  @visibleForTesting
  void onReading(CompassReading reading) {
    final accuracy = reading.accuracy;
    if (accuracy != null && accuracy >= unusableAccuracy) {
      direction.value = null;
      return;
    }
    final declination = _declination;
    final degrees = CameraDirection.normalize(
      reading.magneticDegrees +
          (declination ?? 0) +
          // The front lens looks the opposite way.
          (_isFrontCamera() && !reading.flat ? 180 : 0),
    );
    direction.value = CameraDirection(
      degrees: (degrees * 10).round() / 10,
      accuracy: accuracy == null ? null : (accuracy * 10).round() / 10,
      trueNorth: declination != null,
      flat: reading.flat,
    );
    _readAt = _clock();
  }

  /// The direction for a photo taken now, or null when the compass has
  /// nothing recent and reliable.
  CameraDirection? snapshot() {
    final at = _readAt;
    if (at == null || _clock().difference(at) > maxAge) return null;
    return direction.value;
  }
}
