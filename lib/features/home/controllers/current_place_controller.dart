import 'dart:async';

import 'package:get/get.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/place_info.dart';
import 'package:gps_camera/features/location/services/location_service.dart';
import 'package:gps_camera/features/location/services/place_service.dart';

/// What the home screen can say about where the phone is.
enum CurrentPlaceStatus {
  /// Looking for the first fix.
  locating,

  /// [CurrentPlaceController.fix] is set.
  found,

  /// Location permission not given (yet).
  noPermission,

  /// Location permission refused for good; only system settings can change it.
  blocked,

  /// The phone's location is switched off.
  off,

  /// No fix could be had (indoors, timeout).
  unavailable,
}

/// The phone's current location and address for the home screen. Looks the
/// location up when asked (opening the app, coming back to it, pulling to
/// refresh) and while the home screen stays open, never in the background.
class CurrentPlaceController extends GetxController {
  CurrentPlaceController(
    this._location,
    this._places, {
    this.refreshEvery = const Duration(minutes: 1),
    this.fixTimeout = const Duration(seconds: 20),
  });

  final LocationService _location;
  final PlaceService _places;

  /// How often the location is looked up again while the home screen is
  /// shown.
  final Duration refreshEvery;
  final Duration fixTimeout;

  final Rx<CurrentPlaceStatus> status = CurrentPlaceStatus.locating.obs;
  final Rxn<LocationFix> fix = Rxn<LocationFix>();
  final Rxn<PlaceInfo> place = Rxn<PlaceInfo>();

  Future<void>? _running;
  Timer? _timer;

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  /// Keeps the location fresh while the home screen is visible.
  void resume() {
    unawaited(locate());
    _timer?.cancel();
    _timer = Timer.periodic(refreshEvery, (_) => unawaited(locate()));
  }

  /// Stops looking up (home screen hidden or app in the background).
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// Looks the location up now. Calls during a lookup share it.
  Future<void> locate() =>
      _running ??= _refresh().whenComplete(() => _running = null);

  Future<void> _refresh() async {
    final PermissionAccess access;
    try {
      access = await _location.checkPermission();
    } catch (_) {
      _fail(CurrentPlaceStatus.unavailable);
      return;
    }
    if (access != PermissionAccess.granted) {
      _fail(
        access == PermissionAccess.blocked
            ? CurrentPlaceStatus.blocked
            : CurrentPlaceStatus.noPermission,
      );
      return;
    }
    if (!await _safe(_location.isServiceEnabled, false)) {
      _fail(CurrentPlaceStatus.off);
      return;
    }

    // Something to show at once, then the precise fix.
    if (fix.value == null) {
      final last = await _safe(_location.lastKnownFix, null);
      if (last != null) await _show(last);
    }
    try {
      await _show(await _location.currentFix(timeLimit: fixTimeout));
    } catch (_) {
      // Keep what is shown; say so only when there is nothing. Shown again
      // so its age is rechecked: an old fix then reads "Last known".
      if (fix.value == null) {
        status.value = CurrentPlaceStatus.unavailable;
      } else {
        fix.refresh();
      }
    }
  }

  Future<void> _show(LocationFix next) async {
    fix.value = next;
    status.value = CurrentPlaceStatus.found;
    final known = place.value;
    // The address is looked up again only after moving 25 m, or when the
    // last lookup had none (offline).
    if (known != null &&
        known.hasAddress &&
        PlaceService.distanceMeters(
              known.latitude,
              known.longitude,
              next.latitude,
              next.longitude,
            ) <
            25) {
      return;
    }
    place.value = await _places.describe(next.latitude, next.longitude);
  }

  void _fail(CurrentPlaceStatus reason) {
    status.value = reason;
    fix.value = null;
    place.value = null;
  }

  /// Asks for location permission, or opens the right settings screen when
  /// asking is no longer possible. Then looks the location up.
  Future<void> fixAccess() async {
    switch (status.value) {
      case CurrentPlaceStatus.noPermission:
        await _safe(_location.requestPermission, PermissionAccess.denied);
      case CurrentPlaceStatus.blocked:
        await _safe(_location.openAppSettings, false);
      case CurrentPlaceStatus.off:
        await _safe(_location.openLocationSettings, false);
      case CurrentPlaceStatus.locating ||
          CurrentPlaceStatus.found ||
          CurrentPlaceStatus.unavailable:
        break;
    }
    await locate();
  }

  static Future<T> _safe<T>(Future<T> Function() action, T orElse) async {
    try {
      return await action();
    } catch (_) {
      return orElse;
    }
  }
}
