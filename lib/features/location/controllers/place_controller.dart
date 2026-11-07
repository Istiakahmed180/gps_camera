import 'dart:async';

import 'package:get/get.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/place_info.dart';
import 'package:gps_camera/features/location/services/place_service.dart';
import 'package:gps_camera/features/location/utils/plus_code.dart';

/// Keeps the address of the live GPS position up to date for the camera.
/// Looks up again only after moving [minMove] or after [maxAge], so the
/// geocoder is not called for every fix.
class PlaceController extends GetxController {
  PlaceController(
    this._location,
    this._places, {
    this.minMove = 25,
    this.maxAge = const Duration(minutes: 2),
    this.offlineRetry = const Duration(seconds: 30),
    this.reuseWithin = 30,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Meters moved before the address is looked up again.
  final double minMove;
  final Duration maxAge;

  /// How soon to retry when the last lookup had no address (offline).
  final Duration offlineRetry;

  /// A capture within this many meters reuses the live address.
  final double reuseWithin;

  final LocationController _location;
  final PlaceService _places;
  final DateTime Function() _clock;

  final Rxn<PlaceInfo> place = Rxn<PlaceInfo>();
  final RxBool isLooking = false.obs;

  Worker? _worker;
  Future<PlaceInfo?>? _pending;

  @override
  void onInit() {
    super.onInit();
    _worker = ever<LocationFix?>(
      _location.fix,
      (_) => unawaited(lookUpIfNeeded()),
    );
    unawaited(lookUpIfNeeded());
  }

  @override
  void onClose() {
    _worker?.dispose();
    super.onClose();
  }

  /// Looks up the current fix if needed. Never runs two lookups at once.
  Future<PlaceInfo?> lookUpIfNeeded() {
    final fix = _location.fix.value;
    if (fix == null) return Future.value(place.value);
    if (_pending != null) return _pending!;
    if (!_isOutdated(fix)) return Future.value(place.value);

    isLooking.value = true;
    return _pending = _places
        .describe(fix.latitude, fix.longitude)
        .then<PlaceInfo?>((result) {
          place.value = result;
          return result;
        })
        .whenComplete(() {
          isLooking.value = false;
          _pending = null;
        });
  }

  /// The place to record for a photo taken at [fix]: the live address when
  /// it was looked up close by, otherwise a fresh lookup. Null without a fix.
  Future<PlaceInfo?> placeFor(LocationFix? fix) async {
    if (fix == null) return null;
    final current = place.value;
    if (current != null &&
        current.hasAddress &&
        _distance(current, fix) <= reuseWithin) {
      return current.at(
        fix.latitude,
        fix.longitude,
        PlusCode.encode(fix.latitude, fix.longitude),
      );
    }
    return _places.describe(fix.latitude, fix.longitude);
  }

  bool _isOutdated(LocationFix fix) {
    final current = place.value;
    if (current == null) return true;
    final age = _clock().difference(current.resolvedAt);
    if (!current.hasAddress && age >= offlineRetry) return true;
    return _distance(current, fix) >= minMove || age >= maxAge;
  }

  static double _distance(PlaceInfo place, LocationFix fix) =>
      PlaceService.distanceMeters(
        place.latitude,
        place.longitude,
        fix.latitude,
        fix.longitude,
      );
}
