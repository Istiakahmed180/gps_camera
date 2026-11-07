import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/models/camera_status.dart';
import 'package:gps_camera/features/camera/models/capture_feedback.dart';

typedef CameraLoader = Future<List<CameraDescription>> Function();

/// Owns the camera session: permission, initialization, lifecycle,
/// lens switching, flash and capture.
///
/// Every operation that creates, disposes or uses the native camera runs
/// through [_serial], so lifecycle events, lens switches and captures can
/// never overlap or touch a disposed controller.
class CaptureController extends GetxController with WidgetsBindingObserver {
  CaptureController(
    this._permissions,
    this._photoStorage, {
    CameraLoader cameraLoader = availableCameras,
  }) : _loadCameras = cameraLoader;

  static const List<FlashMode> flashModes = [
    FlashMode.off,
    FlashMode.auto,
    FlashMode.always,
  ];
  static const Duration _feedbackDuration = Duration(milliseconds: 2500);

  final PermissionService _permissions;
  final PhotoStorageService _photoStorage;
  final CameraLoader _loadCameras;

  final Rx<CameraStatus> status = CameraStatus.initializing.obs;
  final Rxn<CameraController> camera = Rxn<CameraController>();
  final Rx<FlashMode> flashMode = FlashMode.off.obs;
  final RxBool isFlashSupported = false.obs;
  final RxBool canSwitchCamera = false.obs;
  final RxBool isCapturing = false.obs;
  final RxnString errorMessage = RxnString();
  final Rxn<CaptureFeedback> feedback = Rxn<CaptureFeedback>();

  /// Local path of the most recent saved photo, for later phases.
  final RxnString lastPhotoPath = RxnString();

  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  Future<void> _pending = Future<void>.value();
  bool _isRequestingPermission = false;
  bool _isClosed = false;
  Timer? _feedbackTimer;

  bool get canCapture =>
      status.value == CameraStatus.ready &&
      !isCapturing.value &&
      (camera.value?.value.isInitialized ?? false);

  bool get canToggleCamera => canSwitchCamera.value && canCapture;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkPermissionAndStart(requestIfNeeded: true));
  }

  @override
  void onClose() {
    _isClosed = true;
    WidgetsBinding.instance.removeObserver(this);
    _feedbackTimer?.cancel();
    unawaited(_serial(_disposeCamera));
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isRequestingPermission || _isClosed) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        unawaited(_serial(_disposeCamera));
      case AppLifecycleState.resumed:
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
          'Flash could not be changed: ${_describe(e)}',
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

  Future<void> capture() async {
    if (!canCapture) return;
    isCapturing.value = true;

    try {
      await _serial(() async {
        final controller = camera.value;
        if (controller == null || !controller.value.isInitialized) {
          throw CameraException('CameraClosed', 'The camera is not ready.');
        }
        final image = await controller.takePicture();
        final saved = await _photoStorage.savePhoto(image);
        lastPhotoPath.value = saved.path;
      });
      _showFeedback('Photo saved');
    } on CameraException catch (e) {
      _showFeedback('Capture failed: ${_describe(e)}', isError: true);
    } on FileSystemException catch (e) {
      _showFeedback('Photo could not be saved: ${e.message}', isError: true);
    } catch (_) {
      _showFeedback('Something went wrong while capturing.', isError: true);
    } finally {
      isCapturing.value = false;
    }
  }

  Future<void> _checkPermissionAndStart({required bool requestIfNeeded}) async {
    if (camera.value != null && status.value == CameraStatus.ready) return;

    var permission = await _safePermission(_permissions.cameraStatus);
    if (permission == CameraPermission.denied && requestIfNeeded) {
      permission = await _request();
    }
    await _applyPermission(permission);
  }

  Future<CameraPermission?> _request() async {
    _isRequestingPermission = true;
    try {
      return await _safePermission(_permissions.requestCamera);
    } finally {
      _isRequestingPermission = false;
    }
  }

  Future<void> _applyPermission(CameraPermission? permission) async {
    if (_isClosed) return;

    switch (permission) {
      case CameraPermission.granted:
        await _serial(_startCamera);
      case CameraPermission.blocked:
        status.value = CameraStatus.permissionBlocked;
      case CameraPermission.denied:
        // Android reports "denied" for a permanently denied permission until
        // it is requested again, so keep the blocked state once known.
        if (status.value != CameraStatus.permissionBlocked) {
          status.value = CameraStatus.permissionDenied;
        }
      case null:
        _setError('Camera permission could not be checked on this device.');
    }
  }

  Future<CameraPermission?> _safePermission(
    Future<CameraPermission> Function() check,
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
      _setError('Cameras could not be listed: ${_describe(e)}');
      return;
    } catch (_) {
      _setError('The camera is not available on this device.');
      return;
    }

    if (_cameras.isEmpty) {
      _setError('No camera was found on this device.');
      return;
    }
    canSwitchCamera.value =
        _cameras.map((c) => c.lensDirection).toSet().length > 1;

    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.veryHigh,
      enableAudio: false,
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
        _setError('The camera could not be started: ${_describe(e)}');
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

  String _describe(CameraException e) => e.description ?? e.code;
}
