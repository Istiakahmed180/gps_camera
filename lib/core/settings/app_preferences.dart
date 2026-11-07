import 'package:get/get.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/core/settings/display_format.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/models/capture_timer.dart';
import 'package:gps_camera/features/camera/models/photo_quality.dart';

/// App-wide preferences edited in Settings.
class AppPreferences extends GetxService {
  AppPreferences(this._storage);

  final StorageService _storage;

  late final Rx<DisplayFormat> displayFormat = _loadFormat().obs;
  late final Rx<PhotoQuality> photoQuality = PhotoQuality.parse(
    _storage.read<String>(StorageKeys.photoQuality),
  ).obs;

  /// Rule-of-thirds lines on the preview. Never part of the photo.
  late final RxBool showGrid =
      (_storage.read<bool>(StorageKeys.cameraGrid) ?? false).obs;

  late final Rx<CaptureTimer> captureTimer = CaptureTimer.parse(
    _storage.read<String>(StorageKeys.captureTimer),
  ).obs;

  /// Volume buttons work as a shutter while the camera is open.
  late final RxBool volumeShutter =
      (_storage.read<bool>(StorageKeys.volumeShutter) ?? true).obs;

  /// Added to every new photo until changed or cleared, like the active
  /// project. Null when there is none.
  late final RxnString captureNote = RxnString(
    PhotoMetadata.cleanNote(_storage.read<String>(StorageKeys.captureNote)),
  );

  Future<void> setCaptureNote(String? value) async {
    final note = PhotoMetadata.cleanNote(value);
    captureNote.value = note;
    if (note == null) {
      await _storage.remove(StorageKeys.captureNote);
    } else {
      await _storage.write(StorageKeys.captureNote, note);
    }
  }

  Future<void> setShowGrid(bool value) async {
    showGrid.value = value;
    await _storage.write(StorageKeys.cameraGrid, value);
  }

  Future<void> setCaptureTimer(CaptureTimer value) async {
    captureTimer.value = value;
    await _storage.write(StorageKeys.captureTimer, value.name);
  }

  Future<void> setVolumeShutter(bool value) async {
    volumeShutter.value = value;
    await _storage.write(StorageKeys.volumeShutter, value);
  }

  @override
  void onInit() {
    super.onInit();
    DisplayFormat.current = displayFormat.value;
  }

  DisplayFormat _loadFormat() {
    final saved = _storage.read<Map<String, dynamic>>(
      StorageKeys.displayFormat,
    );
    return saved == null
        ? const DisplayFormat()
        : DisplayFormat.fromJson(saved);
  }

  Future<void> setDisplayFormat(DisplayFormat format) async {
    displayFormat.value = format;
    DisplayFormat.current = format;
    await _storage.write(StorageKeys.displayFormat, format.toJson());
  }

  Future<void> setPhotoQuality(PhotoQuality quality) async {
    photoQuality.value = quality;
    await _storage.write(StorageKeys.photoQuality, quality.name);
  }
}
