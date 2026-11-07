import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/features/location/services/details_backfill.dart';

/// Runs [DetailsBackfill] shortly after launch, whenever the app comes back
/// to the foreground, and every [interval] while it is open. Each run stops
/// early when the phone is offline, so this costs nothing without internet.
class DetailsBackfillScheduler extends GetxService with WidgetsBindingObserver {
  DetailsBackfillScheduler(
    this._backfill, {
    this.firstDelay = const Duration(seconds: 10),
    this.interval = const Duration(minutes: 10),
  });

  final DetailsBackfill _backfill;
  final Duration firstDelay;
  final Duration interval;

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer(firstDelay, _tick);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 3), _tick);
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  /// True while a run is in progress (automatic or [runNow]).
  final RxBool isRunning = false.obs;

  /// Runs immediately, e.g. from Settings. Null if one is already running.
  Future<BackfillResult?> runNow() async {
    if (isRunning.value) return null;
    isRunning.value = true;
    try {
      final result = await _backfill.run();
      if (result.changedAnything && Get.isRegistered<GalleryController>()) {
        unawaited(Get.find<GalleryController>().reload());
      }
      return result;
    } finally {
      isRunning.value = false;
    }
  }

  Future<void> _tick() async {
    _timer = Timer(interval, _tick);
    try {
      await runNow();
    } on PlatformException {
      // Try again on the next tick.
    } catch (_) {}
  }
}
