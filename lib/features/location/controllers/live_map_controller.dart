import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/services/place_service.dart';
import 'package:gps_camera/features/location/services/static_map_service.dart';

typedef MapServiceFactory = StaticMapService Function(String apiKey);

/// The map image for the current GPS position. The same image is shown in
/// the live overlay and saved with the photo, so preview and copy match.
/// Fetched again only after moving [minMove] meters.
class LiveMapController extends GetxController {
  LiveMapController(
    this._location, {
    this._channel = const MethodChannel('co.tdevs.gps_camera/native'),
    this._serviceFor = StaticMapService.new,
    this.minMove = 25,
  });

  final LocationController _location;
  final MethodChannel _channel;
  final MapServiceFactory _serviceFor;
  final double minMove;

  /// False when no map key was configured; the overlay then says so.
  final RxBool available = false.obs;
  final Rxn<ui.Image> image = Rxn<ui.Image>();

  StaticMapService? _service;
  Uint8List? _bytes;
  LocationFix? _mappedAt;
  Future<void>? _pending;
  Worker? _worker;

  @override
  void onInit() {
    super.onInit();
    unawaited(_init());
  }

  @override
  void onClose() {
    _worker?.dispose();
    image.value?.dispose();
    super.onClose();
  }

  Future<void> _init() async {
    String? key;
    try {
      key = await _channel.invokeMethod<String>('mapKey');
    } catch (_) {
      key = null;
    }
    if (key == null || key.isEmpty || isClosed) return;
    _service = _serviceFor(key);
    available.value = true;
    _worker = ever<LocationFix?>(_location.fix, (_) => unawaited(_update()));
    unawaited(_update());
  }

  /// The map PNG to save with a photo taken now: the shown map when it is
  /// for this spot, otherwise null (never a map of somewhere else).
  Future<Uint8List?> snapshot() async {
    await _pending;
    final fix = _location.fix.value;
    final at = _mappedAt;
    if (fix == null || at == null || _bytes == null) return null;
    return _distance(at, fix) < minMove ? _bytes : null;
  }

  Future<void> _update() {
    final fix = _location.fix.value;
    final service = _service;
    if (fix == null || service == null || _pending != null) {
      return _pending ?? Future.value();
    }
    final at = _mappedAt;
    if (at != null && _bytes != null && _distance(at, fix) < minMove) {
      return Future.value();
    }
    return _pending = _fetch(service, fix).whenComplete(() => _pending = null);
  }

  Future<void> _fetch(StaticMapService service, LocationFix fix) async {
    final bytes = await service.fetch(fix.latitude, fix.longitude);
    if (bytes == null || isClosed) return;
    ui.Image? decoded;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      decoded = (await codec.getNextFrame()).image;
      codec.dispose();
    } catch (_) {
      return;
    }
    if (isClosed) {
      decoded.dispose();
      return;
    }
    final old = image.value;
    _bytes = bytes;
    _mappedAt = fix;
    image.value = decoded;
    old?.dispose();
  }

  static double _distance(LocationFix a, LocationFix b) =>
      PlaceService.distanceMeters(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      );
}
