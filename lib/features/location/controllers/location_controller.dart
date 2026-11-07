import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/models/location_status.dart';
import 'package:gps_camera/features/location/services/location_service.dart';

typedef Clock = DateTime Function();

/// Foreground GPS tracking for the camera screen.
///
/// Holds at most one position subscription. Updates stop when the app is
/// backgrounded or the screen closes, and restart on resume.
///
/// [fix] is the best fix from the last [selectionWindow], not just the
/// latest: the fused provider can briefly fall back to a coarse network fix
/// (hundreds of meters) between good GPS fixes. Older fixes are penalised by
/// [assumedSpeed] per second of age so a slightly better but older fix never
/// wins once the user may have moved. The chosen fix keeps its real accuracy
/// and timestamp.
class LocationController extends GetxController with WidgetsBindingObserver {
  LocationController(
    this._service,
    this._permissions, {
    this.maxFixAge = const Duration(seconds: 30),
    this.firstFixTimeout = const Duration(seconds: 30),
    this.selectionWindow = const Duration(seconds: 10),
    this.assumedSpeed = 1.5,
    this.clock = DateTime.now,
  });

  /// Fixes older than this are not considered when choosing the best fix.
  final Duration selectionWindow;

  /// Meters per second added to an older fix's accuracy when comparing.
  final double assumedSpeed;

  /// A fix older than this is reported as stale, never as current.
  final Duration maxFixAge;

  /// Without any fix after this long, GPS is reported unavailable.
  final Duration firstFixTimeout;

  final LocationService _service;
  final PermissionService _permissions;

  /// Injectable for tests.
  final Clock clock;

  final Rx<LocationStatus> status = LocationStatus.idle.obs;
  final Rxn<LocationFix> fix = Rxn<LocationFix>();
  final RxBool isStale = false.obs;

  final List<LocationFix> _recent = [];
  StreamSubscription<LocationFix>? _fixes;
  StreamSubscription<bool>? _serviceChanges;
  Timer? _firstFixTimer;
  Timer? _staleTicker;
  bool _active = false;
  bool _isClosed = false;

  GpsAccuracyLevel? get accuracyLevel {
    final current = fix.value;
    return current == null
        ? null
        : GpsAccuracyLevel.fromMeters(current.accuracy);
  }

  bool get isTracking => _fixes != null;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    _isClosed = true;
    _active = false;
    WidgetsBinding.instance.removeObserver(this);
    _stopUpdates();
    unawaited(_serviceChanges?.cancel());
    _serviceChanges = null;
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_active || _isClosed || _permissions.isRequesting) return;

    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _stopUpdates();
      case AppLifecycleState.resumed:
        unawaited(_refresh(requestIfNeeded: false));
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Begins tracking, asking for permission if it has never been decided.
  Future<void> start() async {
    if (_isClosed) return;
    _active = true;
    _listenToServiceChanges();
    await _refresh(requestIfNeeded: true);
  }

  /// Stops updates while another screen covers the camera.
  void suspend() {
    _active = false;
    _stopUpdates();
  }

  /// Restarts updates after [suspend] without prompting for permission.
  Future<void> resume() async {
    if (_isClosed) return;
    _active = true;
    _listenToServiceChanges();
    await _refresh(requestIfNeeded: false);
  }

  Future<void> requestPermission() async {
    final access = await _safe(_service.requestPermission);
    await _applyPermission(access);
  }

  Future<void> openAppSettings() => _service.openAppSettings();

  Future<void> openLocationSettings() => _service.openLocationSettings();

  Future<void> retry() => _refresh(requestIfNeeded: true);

  /// What to record for a photo captured at [time]. Only a fix that is
  /// recent and from active tracking counts as current.
  LocationSnapshot snapshotAt(DateTime time) {
    final current = _bestAt(time) ?? fix.value;
    if (current == null) {
      return LocationSnapshot.unavailable(_unavailableReason());
    }
    final age = current.ageAt(time);
    final isLive = status.value == LocationStatus.ready && isTracking;
    return isLive && age <= maxFixAge
        ? LocationSnapshot.current(current, age)
        : LocationSnapshot.stale(current, age);
  }

  Future<void> _refresh({required bool requestIfNeeded}) async {
    if (_isClosed || !_active) return;

    final enabled = await _safe(_service.isServiceEnabled);
    if (enabled == false) {
      _setServiceDisabled();
      return;
    }

    var access = await _safe(_service.checkPermission);
    if (access == PermissionAccess.denied && requestIfNeeded) {
      access = await _safe(_service.requestPermission);
    }
    await _applyPermission(access);
  }

  Future<void> _applyPermission(PermissionAccess? access) async {
    if (_isClosed) return;

    switch (access) {
      case PermissionAccess.granted:
        _startUpdates();
      case PermissionAccess.blocked:
        _stopUpdates();
        status.value = LocationStatus.permissionBlocked;
      case PermissionAccess.denied:
        _stopUpdates();
        // Android reports "denied" for a permanently denied permission until
        // it is requested again, so keep the blocked state once known.
        if (status.value != LocationStatus.permissionBlocked) {
          status.value = LocationStatus.permissionDenied;
        }
      case null:
        _stopUpdates();
        status.value = LocationStatus.unavailable;
    }
  }

  void _startUpdates() {
    if (_isClosed || !_active || _fixes != null) return;

    // A held fix that is already old is not "ready": wait for a fresh one.
    final held = fix.value;
    status.value = held == null || held.ageAt(clock()) > maxFixAge
        ? LocationStatus.acquiring
        : LocationStatus.ready;
    _updateStaleness();

    _fixes = _service.fixes().listen(
      _onFix,
      onError: _onError,
      onDone: () => _fixes = null,
    );
    _staleTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateStaleness(),
    );
    _firstFixTimer = Timer(firstFixTimeout, () {
      if (status.value != LocationStatus.acquiring) return;
      // No fresh fix: report unavailable, or keep showing the last known
      // fix as stale (the panel then says the signal was lost).
      status.value = fix.value == null
          ? LocationStatus.unavailable
          : LocationStatus.ready;
    });
  }

  void _stopUpdates() {
    unawaited(_fixes?.cancel());
    _fixes = null;
    _firstFixTimer?.cancel();
    _firstFixTimer = null;
    _staleTicker?.cancel();
    _staleTicker = null;
    _updateStaleness();
  }

  void _onFix(LocationFix next) {
    if (_isClosed) return;
    _firstFixTimer?.cancel();
    _recent.add(next);
    final now = clock();
    _recent.removeWhere((f) => f.ageAt(now) > selectionWindow);
    fix.value = _bestAt(now) ?? next;
    status.value = LocationStatus.ready;
    _updateStaleness();
  }

  void _onError(Object error) {
    if (_isClosed) return;
    final kind = error is LocationException
        ? error.kind
        : LocationErrorKind.unavailable;

    switch (kind) {
      case LocationErrorKind.serviceDisabled:
        _setServiceDisabled();
      case LocationErrorKind.permissionDenied:
        // Revoked while running: stop, then report the real permission state.
        _stopUpdates();
        unawaited(_refresh(requestIfNeeded: false));
      case LocationErrorKind.unavailable:
        if (fix.value == null) status.value = LocationStatus.unavailable;
    }
  }

  /// Lowest age-penalised accuracy among fixes inside [selectionWindow].
  LocationFix? _bestAt(DateTime time) {
    LocationFix? best;
    var bestScore = double.infinity;
    for (final candidate in _recent) {
      final age = candidate.ageAt(time);
      if (age > selectionWindow) continue;
      final score =
          candidate.accuracy +
          age.inMilliseconds / Duration.millisecondsPerSecond * assumedSpeed;
      if (score < bestScore ||
          (score == bestScore &&
              candidate.timestamp.isAfter(best!.timestamp))) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  void _setServiceDisabled() {
    _stopUpdates();
    status.value = LocationStatus.serviceDisabled;
  }

  void _listenToServiceChanges() {
    if (_serviceChanges != null) return;
    try {
      _serviceChanges = _service.serviceStatusChanges().listen((enabled) {
        if (!_active || _isClosed) return;
        if (enabled) {
          unawaited(_refresh(requestIfNeeded: false));
        } else {
          _setServiceDisabled();
        }
      }, onError: (Object _) {});
    } catch (_) {
      // Not supported on this platform; resume checks still cover changes.
    }
  }

  void _updateStaleness() {
    final current = fix.value;
    isStale.value =
        current != null && (!isTracking || current.ageAt(clock()) > maxFixAge);
  }

  LocationUnavailableReason _unavailableReason() {
    return switch (status.value) {
      LocationStatus.permissionDenied || LocationStatus.permissionBlocked =>
        LocationUnavailableReason.permissionDenied,
      LocationStatus.serviceDisabled =>
        LocationUnavailableReason.locationServicesDisabled,
      LocationStatus.unavailable => LocationUnavailableReason.gpsUnavailable,
      LocationStatus.idle ||
      LocationStatus.acquiring ||
      LocationStatus.ready => LocationUnavailableReason.noFixYet,
    };
  }

  Future<T?> _safe<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return null;
    }
  }
}
