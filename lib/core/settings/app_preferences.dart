import 'package:get/get.dart';
import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/core/settings/display_format.dart';
import 'package:gps_camera/features/camera/models/photo_quality.dart';

/// App-wide preferences edited in Settings.
class AppPreferences extends GetxService {
  AppPreferences(this._storage);

  final StorageService _storage;

  late final Rx<DisplayFormat> displayFormat = _loadFormat().obs;
  late final Rx<PhotoQuality> photoQuality = PhotoQuality.parse(
    _storage.read<String>(StorageKeys.photoQuality),
  ).obs;

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
