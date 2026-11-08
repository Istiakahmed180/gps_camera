import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gps_camera/features/camera/models/capture_timer.dart';
import 'package:gps_camera/features/camera/models/photo_quality.dart';
import 'package:gps_camera/features/camera/services/volume_shutter.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/features/camera/models/camera_status.dart';
import 'package:gps_camera/features/camera/models/capture_assignment.dart';
import 'package:gps_camera/features/camera/models/capture_mode.dart';
import 'package:gps_camera/features/camera/models/video_details.dart';
import 'package:gps_camera/features/camera/models/capture_post_processing.dart';
import 'package:gps_camera/features/camera/models/capture_feedback.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/video/services/video_stamp_service.dart';
import 'package:gps_camera/features/location/models/camera_direction.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';

typedef CameraLoader = Future<List<CameraDescription>> Function();

/// Owns the camera session: permission, initialization, lifecycle,
/// lens switching, flash and capture. Location tracking lives in
/// [LocationController]; this controller only starts it and reads a
/// snapshot when a photo is taken.
///
/// Every operation that creates, disposes or uses the native camera runs
/// through [_serial], so lifecycle events, lens switches and captures can
/// never overlap or touch a disposed controller.
class CaptureController extends GetxController with WidgetsBindingObserver {
  CaptureController(
    this._permissions,
    this._saver,
    this._location, {
    CameraLoader cameraLoader = availableCameras,
    this._assigner,
    this._postProcessor,
    PhotoQuality Function()? quality,
    CaptureTimer Function()? timer,
    this._volume,
    bool Function()? volumeEnabled,
    String? Function()? note,
    CameraDirection? Function()? direction,
  }) : _loadCameras = cameraLoader,
       _note = note ?? (() => null),
       _direction = direction ?? (() => null),
       _quality = quality ?? (() => PhotoQuality.fallback),
       _timer = timer ?? (() => CaptureTimer.off),
       _volumeEnabled = volumeEnabled ?? (() => true);

  final CaptureTimer Function() _timer;

  /// The note added to new photos, read at the shutter.
  final String? Function() _note;

  /// The compass direction, read at the shutter.
  final CameraDirection? Function() _direction;

  /// True while the front (selfie) camera is in use.
  bool get isFrontCamera =>
      _cameras.isNotEmpty &&
      _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;

  /// Volume buttons as a shutter; null disables the feature.
  final VolumeShutter? _volume;
  final bool Function() _volumeEnabled;

  /// Highest zoom offered. Beyond this, digital zoom only adds blur.
  static const double maxUsefulZoom = 10;

  final RxDouble zoom = 1.0.obs;
  final RxDouble minZoom = 1.0.obs;
  final RxDouble maxZoom = 1.0.obs;
  double? _zoomTarget;
  bool _zoomBusy = false;

  /// Where the user tapped to focus, as a fraction of the preview, and a
  /// counter that changes on every tap so the ring animates again.
  final Rxn<Offset> focusPoint = Rxn<Offset>();
  final RxInt focusTaps = 0.obs;
  Timer? _focusReset;

  /// Seconds left before a timed photo, or null when no timer is running.
  final RxnInt countdown = RxnInt();
  Timer? _countdownTimer;

  /// Read each time the camera opens, so a change in Settings applies the
  /// next time the camera screen is used.
  final PhotoQuality Function() _quality;

  /// Files new captures into the active project. Optional: the camera works
  /// the same without it, and its failures never fail a capture.
  final CaptureAssigner? _assigner;

  /// Map snapshot, address and automatic watermarked copy, done after the
  /// photo is saved. Optional; never delays or fails a capture.
  final CapturePostProcessor? _postProcessor;
  Future<void> _postQueue = Future<void>.value();

  static const List<FlashMode> flashModes = [
    FlashMode.off,
    FlashMode.auto,
    FlashMode.always,
  ];
  static const Duration _feedbackDuration = Duration(milliseconds: 2500);

  final PermissionService _permissions;
  final CaptureSaver _saver;
  final LocationController _location;
  final CameraLoader _loadCameras;

  final Rx<CameraStatus> status = CameraStatus.initializing.obs;
  final Rxn<CameraController> camera = Rxn<CameraController>();
  final Rx<FlashMode> flashMode = FlashMode.off.obs;
  final RxBool isFlashSupported = false.obs;
  final RxBool canSwitchCamera = false.obs;
  final RxBool isCapturing = false.obs;

  /// Photo or video. Changing it restarts the camera with the right
  /// settings (video: Full HD, sound when allowed).
  final Rx<CaptureMode> mode = CaptureMode.photo.obs;

  /// True while a video is being recorded.
  final RxBool isRecording = false.obs;

  /// How long the current video has been recording.
  final Rx<Duration> recordingTime = Duration.zero.obs;

  /// Longest video recorded in one go; recording stops by itself after it.
  static const Duration maxVideoLength = Duration(minutes: 10);

  _Recording? _recording;
  Timer? _recordTimer;

  /// Whether sound may be recorded; checked when video mode starts.
  bool _microphone = false;

  /// True between leaving the app and coming back.
  bool _inBackground = false;
  final RxnString errorMessage = RxnString();
  final Rxn<CaptureFeedback> feedback = Rxn<CaptureFeedback>();

  /// Local path of the most recent saved photo, for later phases.
  final RxnString lastPhotoPath = RxnString();

  /// The most recent capture, including its metadata sidecar.
  final Rxn<SavedCapture> lastCapture = Rxn<SavedCapture>();

  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  Future<void> _pending = Future<void>.value();
  bool _isClosed = false;

  /// True while another screen (the watermark editor) covers the camera.
  bool _isSuspended = false;
  Timer? _feedbackTimer;

  bool get canCapture =>
      status.value == CameraStatus.ready &&
      !isCapturing.value &&
      !isRecording.value &&
      (camera.value?.value.isInitialized ?? false);

  /// The shutter can be pressed: to capture, or to stop a recording.
  bool get canPressShutter =>
      canCapture || isRecording.value || countdown.value != null;

  bool get canToggleCamera => canSwitchCamera.value && canCapture;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _setVolumeShutter(true);
    unawaited(_initialSetup());
  }

  /// Camera permission first, then location, so the two system dialogs
  /// never overlap.
  Future<void> _initialSetup() async {
    await _checkPermissionAndStart(requestIfNeeded: true);
    if (!_isClosed) await _location.start();
  }

  @override
  void onClose() {
    _isClosed = true;
    WidgetsBinding.instance.removeObserver(this);
    _feedbackTimer?.cancel();
    _focusReset?.cancel();
    _cancelCountdown();
    _setVolumeShutter(false);
    unawaited(stopRecording().then((_) => _serial(_disposeCamera)));
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_permissions.isRequesting || _isClosed || _isSuspended) return;

    switch (state) {
      // Pulling down the notification shade only makes the app inactive;
      // a recording keeps going until the app is really left.
      case AppLifecycleState.inactive when isRecording.value:
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (state != AppLifecycleState.inactive) _inBackground = true;
        _cancelCountdown();
        // A recording is saved before the camera is let go.
        unawaited(stopRecording().then((_) => _serial(_disposeCamera)));
      case AppLifecycleState.resumed:
        _inBackground = false;
        unawaited(_checkPermissionAndStart(requestIfNeeded: false));
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> requestPermission() async {
    final result = await _request();
    await _applyPermission(result);
  }

  Future<void> openSettings() => _permissions.openSettings();

  Future<void> retry() => _checkPermissionAndStart(requestIfNeeded: true);

  void close() => Get.back<void>();

  /// Opens the watermark editor for the latest capture. The camera and GPS
  /// are released while the editor is open and restarted afterwards.
  Future<void> openWatermarkEditor() async {
    final path = lastPhotoPath.value;
    if (path == null ||
        isCapturing.value ||
        isRecording.value ||
        _isSuspended) {
      return;
    }

    _isSuspended = true;
    _cancelCountdown();
    _setVolumeShutter(false);
    _location.suspend();
    await _serial(_disposeCamera);
    try {
      // Videos are stamped automatically; their thumbnail opens the gallery.
      if (isVideoPath(path)) {
        await Get.toNamed<void>(AppRoutes.gallery);
      } else {
        await Get.toNamed<void>(AppRoutes.watermark, arguments: path);
      }
    } finally {
      _isSuspended = false;
      if (!_isClosed) {
        _setVolumeShutter(true);
        unawaited(_location.resume());
        await _checkPermissionAndStart(requestIfNeeded: false);
      }
    }
  }

  Future<void> cycleFlashMode() async {
    final controller = camera.value;
    if (controller == null || !isFlashSupported.value || !canCapture) return;

    final next =
        flashModes[(flashModes.indexOf(flashMode.value) + 1) %
            flashModes.length];
    await _serial(() async {
      if (camera.value != controller) return;
      try {
        await controller.setFlashMode(next);
        flashMode.value = next;
      } on CameraException catch (e) {
        _showFeedback(
          'Flash could not be changed: @error'.trParams({
            'error': _describe(e),
          }),
          isError: true,
        );
      }
    });
  }

  Future<void> switchCamera() async {
    if (!canToggleCamera) return;

    final current = _cameras[_cameraIndex].lensDirection;
    final nextIndex = _cameras.indexWhere((c) => c.lensDirection != current);
    _cameraIndex = nextIndex == -1
        ? (_cameraIndex + 1) % _cameras.length
        : nextIndex;

    await _serial(() async {
      await _disposeCamera();
      await _startCamera();
    });
  }

  /// The shutter button and volume keys: takes a photo now, starts the
  /// timer, or cancels a running timer.
  void shutter() {
    if (countdown.value != null) {
      _cancelCountdown();
      return;
    }
    if (isRecording.value) {
      unawaited(stopRecording());
      return;
    }
    if (!canCapture) return;
    final seconds = _timer().seconds;
    Future<void> go() => mode.value.isVideo ? startRecording() : capture();
    if (seconds == 0) {
      unawaited(go());
      return;
    }
    countdown.value = seconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = (countdown.value ?? 1) - 1;
      if (left > 0) {
        countdown.value = left;
        return;
      }
      _cancelCountdown();
      unawaited(go());
    });
  }

  /// Switches between photo and video. The first switch to video asks for
  /// the microphone; without it videos are recorded silently.
  Future<void> setMode(CaptureMode value) async {
    if (value == mode.value || isRecording.value || isCapturing.value) return;
    _cancelCountdown();
    if (value.isVideo) {
      var access = await _safePermission(_permissions.microphoneStatus);
      if (access == PermissionAccess.denied) {
        access = await _safePermission(_permissions.requestMicrophone);
      }
      _microphone = access == PermissionAccess.granted;
      if (_isClosed) return;
    }
    mode.value = value;
    await _serial(() async {
      await _disposeCamera();
      await _startCamera();
    });
  }

  /// Starts recording a video; its start time, location, note and
  /// direction are taken once recording has begun, and the location every
  /// second after.
  Future<void> startRecording() async {
    if (!canCapture || !mode.value.isVideo) return;
    final controller = camera.value!;
    final note = _note();
    final map = _postProcessor?.grabMap();
    isCapturing.value = true;
    // Stamping another video now would compete for the video encoder.
    _holdStamps(true);
    try {
      await _serial(controller.startVideoRecording);
    } on CameraException catch (e) {
      _holdStamps(false);
      _showFeedback(
        'Recording failed: @error'.trParams({'error': _describe(e)}),
        isError: true,
      );
      return;
    } finally {
      isCapturing.value = false;
    }
    // The screen closed, the app was left or the camera changed while
    // recording started: drop this start instead of a recording that
    // nothing can stop.
    if (_isClosed ||
        _inBackground ||
        camera.value != controller ||
        !controller.value.isRecordingVideo) {
      _holdStamps(false);
      try {
        final file = await controller.stopVideoRecording();
        await File(file.path).delete();
      } catch (_) {}
      return;
    }

    final startedAt = DateTime.now();
    final recording = _Recording(
      startedAt: startedAt,
      location: _location.snapshotAt(startedAt),
      note: note,
      direction: _direction(),
      map: map,
    )..mark(0, _location.snapshotAt(startedAt), _direction());
    _recording = recording;
    recordingTime.value = Duration.zero;
    isRecording.value = true;
    unawaited(_saver.writeJournal(recording.journal));
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final elapsed = now.difference(startedAt);
      recordingTime.value = elapsed;
      recording.mark(
        elapsed.inMilliseconds,
        _location.snapshotAt(now),
        _direction(),
      );
      if (elapsed.inSeconds % 5 == 0) {
        unawaited(_saver.writeJournal(recording.journal));
      }
      if (elapsed >= maxVideoLength) unawaited(stopRecording());
    });
  }

  void _holdStamps(bool on) {
    if (Get.isRegistered<VideoStampService>()) {
      Get.find<VideoStampService>().hold.value = on;
    }
  }

  /// Stops a recording and saves it; does nothing when not recording.
  Future<void> stopRecording() async {
    final recording = _recording;
    if (recording == null || !isRecording.value) return;
    _recording = null;
    _recordTimer?.cancel();
    _recordTimer = null;
    isRecording.value = false;
    isCapturing.value = true;
    try {
      var saved = await _serial(() async {
        final controller = camera.value;
        // The camera stops recording by itself when the app is left.
        if (controller == null || !controller.value.isRecordingVideo) {
          return null;
        }
        final file = await controller.stopVideoRecording();
        return _saver.saveVideo(
          file,
          startedAt: recording.startedAt,
          location: recording.location,
          track: recording.track,
          note: recording.note,
          direction: recording.direction,
        );
      });
      // The camera finishes the file in the cache by itself; give it a
      // moment, then save it from the journal.
      if (saved == null) await Future<void>.delayed(const Duration(seconds: 2));
      saved ??= await _saver.recoverRecording(
        temporaryDirectory: getTemporaryDirectory,
        settled: const Duration(milliseconds: 1500),
      );
      if (saved == null) {
        throw CameraException('CameraClosed', 'The recording was stopped.');
      }
      lastCapture.value = saved;
      lastPhotoPath.value = saved.photo.path;
      final assignment = await _assign(saved.photo);
      _showFeedback(
        captureFeedbackMessage(saved, assignment),
        isError: !saved.hasMetadataFile || assignment is AssignmentFailed,
      );
      // Saved: the journal is no longer needed for recovery.
      unawaited(_saver.clearJournal());
      _postProcess(saved, recording.map);
    } on CameraException catch (e) {
      // The journal stays, so the recording can be recovered next time.
      _showFeedback(
        'Recording failed: @error'.trParams({'error': _describe(e)}),
        isError: true,
      );
    } on FileSystemException catch (e) {
      _showFeedback(
        'Video could not be saved: @error'.trParams({'error': e.message}),
        isError: true,
      );
    } catch (_) {
      _showFeedback('Something went wrong while recording.'.tr, isError: true);
    } finally {
      isCapturing.value = false;
      recordingTime.value = Duration.zero;
      _holdStamps(false);
    }
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    countdown.value = null;
  }

  void _setVolumeShutter(bool on) {
    final volume = _volume;
    if (volume == null) return;
    if (on && _volumeEnabled()) {
      unawaited(volume.enable(shutter));
    } else {
      unawaited(volume.disable());
    }
  }

  /// Zoom presets the phone supports, e.g. 0.6×, 1×, 2×, 5×, 10×.
  List<double> get zoomPresets {
    final min = minZoom.value;
    final max = maxZoom.value;
    return [
      if (min < 0.95) (min * 10).ceil() / 10,
      for (final z in const [1.0, 2.0, 5.0, 10.0])
        if (z >= min && z <= max + 0.01) z,
    ];
  }

  /// Applies the latest requested zoom; pinch updates arriving faster than
  /// the camera can follow are merged.
  void setZoom(double value) {
    if (camera.value == null || status.value != CameraStatus.ready) return;
    final next = value.clamp(minZoom.value, maxZoom.value).toDouble();
    zoom.value = next;
    _zoomTarget = next;
    if (!_zoomBusy) unawaited(_applyZoom());
  }

  Future<void> _applyZoom() async {
    _zoomBusy = true;
    try {
      while (_zoomTarget != null) {
        final target = _zoomTarget!;
        _zoomTarget = null;
        final controller = camera.value;
        if (controller == null) break;
        try {
          await controller.setZoomLevel(target);
        } on CameraException {
          // Keep the last zoom the camera accepted.
        }
      }
    } finally {
      _zoomBusy = false;
    }
  }

  Future<void> _readZoomRange(CameraController controller) async {
    try {
      minZoom.value = await controller.getMinZoomLevel();
      maxZoom.value = math.max(
        minZoom.value,
        math.min(await controller.getMaxZoomLevel(), maxUsefulZoom),
      );
    } catch (_) {
      minZoom.value = 1;
      maxZoom.value = 1;
    }
    // A new session starts at 1× (or the nearest zoom the lens allows).
    zoom.value = 1.0.clamp(minZoom.value, maxZoom.value).toDouble();
  }

  /// Focuses and meters on [point], given as a fraction of the preview
  /// (0,0 top-left). Returns to automatic after a few seconds.
  Future<void> focusAt(Offset point) async {
    final controller = camera.value;
    if (controller == null || status.value != CameraStatus.ready) return;
    final value = controller.value;
    if (!value.focusPointSupported && !value.exposurePointSupported) return;
    final p = Offset(
      point.dx.clamp(0.0, 1.0).toDouble(),
      point.dy.clamp(0.0, 1.0).toDouble(),
    );
    focusPoint.value = p;
    focusTaps.value++;
    _focusReset?.cancel();
    try {
      if (value.exposurePointSupported) await controller.setExposurePoint(p);
      if (value.focusPointSupported) {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setFocusPoint(p);
      }
    } on CameraException {
      // The tap still shows; the camera keeps its own focus.
    }
    _focusReset = Timer(const Duration(seconds: 6), _resetFocus);
  }

  Future<void> _resetFocus() async {
    focusPoint.value = null;
    final controller = camera.value;
    if (controller == null) return;
    try {
      if (controller.value.exposurePointSupported) {
        await controller.setExposurePoint(null);
      }
      if (controller.value.focusPointSupported) {
        await controller.setFocusPoint(null);
      }
    } on CameraException {
      // Already back to automatic or closed.
    }
  }

  Future<void> capture() async {
    if (!canCapture) return;
    isCapturing.value = true;
    final capturedAt = DateTime.now();
    final location = _location.snapshotAt(capturedAt);
    final note = _note();
    final direction = _direction();
    // The map is grabbed at the shutter, while it still shows this spot.
    final map = _postProcessor?.grabMap();

    try {
      final saved = await _serial(() async {
        final controller = camera.value;
        if (controller == null || !controller.value.isInitialized) {
          throw CameraException('CameraClosed', 'The camera is not ready.');
        }
        final image = await controller.takePicture();
        return _saver.save(
          image,
          capturedAt: capturedAt,
          location: location,
          note: note,
          direction: direction,
        );
      });
      lastCapture.value = saved;
      lastPhotoPath.value = saved.photo.path;
      final assignment = await _assign(saved.photo);
      _showFeedback(
        captureFeedbackMessage(saved, assignment),
        isError: !saved.hasMetadataFile || assignment is AssignmentFailed,
      );
      _postProcess(saved, map);
    } on CameraException catch (e) {
      _showFeedback(
        'Capture failed: @error'.trParams({'error': _describe(e)}),
        isError: true,
      );
    } on FileSystemException catch (e) {
      _showFeedback(
        'Photo could not be saved: @error'.trParams({'error': e.message}),
        isError: true,
      );
    } catch (_) {
      _showFeedback('Something went wrong while capturing.'.tr, isError: true);
    } finally {
      isCapturing.value = false;
    }
  }

  /// Runs post-processing one capture at a time, in capture order.
  void _postProcess(SavedCapture saved, Future<Uint8List?>? map) {
    final processor = _postProcessor;
    if (processor == null) return;
    _postQueue = _postQueue.then((_) async {
      try {
        final result = await processor.process(saved, await map);
        if (result != null && !_isClosed) {
          _showFeedback(result.message, isError: result.isError);
        }
      } catch (_) {
        // Post-processing is best effort; the photo is already saved.
      }
    });
  }

  Future<void> _checkPermissionAndStart({required bool requestIfNeeded}) async {
    if (camera.value != null && status.value == CameraStatus.ready) return;

    var permission = await _safePermission(_permissions.cameraStatus);
    if (permission == PermissionAccess.denied && requestIfNeeded) {
      permission = await _request();
    }
    await _applyPermission(permission);
  }

  Future<PermissionAccess?> _request() =>
      _safePermission(_permissions.requestCamera);

  Future<void> _applyPermission(PermissionAccess? permission) async {
    if (_isClosed) return;

    switch (permission) {
      case PermissionAccess.granted:
        await _serial(_startCamera);
      case PermissionAccess.blocked:
        status.value = CameraStatus.permissionBlocked;
      case PermissionAccess.denied:
        // Android reports "denied" for a permanently denied permission until
        // it is requested again, so keep the blocked state once known.
        if (status.value != CameraStatus.permissionBlocked) {
          status.value = CameraStatus.permissionDenied;
        }
      case null:
        _setError('Camera permission could not be checked on this device.'.tr);
    }
  }

  Future<PermissionAccess?> _safePermission(
    Future<PermissionAccess> Function() check,
  ) async {
    try {
      return await check();
    } catch (_) {
      return null;
    }
  }

  Future<void> _startCamera() async {
    if (_isClosed || camera.value != null) return;
    status.value = CameraStatus.initializing;

    try {
      if (_cameras.isEmpty) {
        _cameras = await _loadCameras();
        _cameraIndex = _defaultCameraIndex(_cameras);
      }
    } on CameraException catch (e) {
      _setError(
        'Cameras could not be listed: @error'.trParams({'error': _describe(e)}),
      );
      return;
    } catch (_) {
      _setError('The camera is not available on this device.'.tr);
      return;
    }

    if (_cameras.isEmpty) {
      _setError('No camera was found on this device.'.tr);
      return;
    }
    canSwitchCamera.value =
        _cameras.map((c) => c.lensDirection).toSet().length > 1;

    final video = mode.value.isVideo;
    final controller = CameraController(
      _cameras[_cameraIndex],
      // Full HD keeps videos a sensible size and quick to stamp.
      video ? ResolutionPreset.veryHigh : _quality().preset,
      enableAudio: video && _microphone,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      _handleInitError(e);
      return;
    }

    if (_isClosed) {
      await controller.dispose();
      return;
    }

    isFlashSupported.value = await _applyFlash(controller);
    await _readZoomRange(controller);
    focusPoint.value = null;
    camera.value = controller;
    errorMessage.value = null;
    status.value = CameraStatus.ready;
  }

  Future<bool> _applyFlash(CameraController controller) async {
    if (controller.description.lensDirection == CameraLensDirection.front) {
      return false;
    }
    try {
      await controller.setFlashMode(flashMode.value);
      return true;
    } on CameraException {
      return false;
    }
  }

  Future<void> _disposeCamera() async {
    final controller = camera.value;
    if (controller == null) return;
    camera.value = null;
    if (!_isClosed && status.value == CameraStatus.ready) {
      status.value = CameraStatus.initializing;
    }
    await controller.dispose();
  }

  void _handleInitError(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
        status.value = CameraStatus.permissionDenied;
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        status.value = CameraStatus.permissionBlocked;
      default:
        _setError(
          'The camera could not be started: @error'.trParams({
            'error': _describe(e),
          }),
        );
    }
  }

  int _defaultCameraIndex(List<CameraDescription> cameras) {
    final back = cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    return back == -1 ? 0 : back;
  }

  /// Runs camera operations one after another.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  void _setError(String message) {
    if (_isClosed) return;
    errorMessage.value = message;
    status.value = CameraStatus.error;
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (_isClosed) return;
    _feedbackTimer?.cancel();
    feedback.value = CaptureFeedback(message, isError: isError);
    _feedbackTimer = Timer(_feedbackDuration, () => feedback.value = null);
  }

  Future<CaptureAssignment> _assign(File photo) async {
    final assigner = _assigner;
    if (assigner == null) return const NotAssigned();
    try {
      return await assigner
          .assignCapture(photo)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return AssignmentFailed('the project'.tr);
    }
  }

  /// Tells the user what was recorded, without overstating GPS quality.
  @visibleForTesting
  static String captureFeedbackMessage(
    SavedCapture saved, [
    CaptureAssignment assignment = const NotAssigned(),
  ]) {
    final base = _locationMessage(saved);
    return switch (assignment) {
      NotAssigned() => base,
      AssignedToProject(:final projectName) => '$base · $projectName',
      AssignmentFailed(:final projectName) =>
        '@base, but it could not be added to @project'.trParams({
          'base': base,
          'project': projectName,
        }),
    };
  }

  static String _locationMessage(SavedCapture saved) {
    final video = saved.metadata.isVideo;
    if (!saved.hasMetadataFile) {
      return video
          ? 'Video saved, but its location data could not be saved'.tr
          : 'Photo saved, but its location data could not be saved'.tr;
    }
    final location = saved.metadata.location;
    return switch (location.status) {
      LocationRecordStatus.unavailable =>
        (video ? 'Video saved · no location' : 'Photo saved · no location').tr,
      LocationRecordStatus.stale =>
        (video
                ? 'Video saved · last known location'
                : 'Photo saved · last known location')
            .tr,
      LocationRecordStatus.current
          when location.accuracyLevel == GpsAccuracyLevel.poor =>
        (video
                ? 'Video saved · poor GPS accuracy'
                : 'Photo saved · poor GPS accuracy')
            .tr,
      LocationRecordStatus.current =>
        (video ? 'Video saved with location' : 'Photo saved with location').tr,
    };
  }

  String _describe(CameraException e) => e.description ?? e.code;
}

/// What is known about a video while it records.
class _Recording {
  _Recording({
    required this.startedAt,
    required this.location,
    this.note,
    this.direction,
    this.map,
  });

  final DateTime startedAt;
  final LocationSnapshot location;
  final String? note;
  final CameraDirection? direction;
  final Future<Uint8List?>? map;
  final List<VideoTrackPoint> track = [];

  RecordingJournal get journal => RecordingJournal(
    startedAt: startedAt,
    location: location,
    note: note,
    direction: direction,
    track: List.of(track),
  );

  void mark(int atMs, LocationSnapshot location, CameraDirection? direction) =>
      track.add(
        VideoTrackPoint(atMs: atMs, location: location, direction: direction),
      );
}
