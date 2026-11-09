import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';

class WatermarkSettingsStore {
  WatermarkSettingsStore(this._storage);

  final StorageService _storage;

  WatermarkConfig load() {
    final saved = _storage.read<Map<String, dynamic>>(
      StorageKeys.watermarkConfig,
    );
    if (saved == null) return const WatermarkConfig();
    final config = WatermarkConfig.fromJson(saved);
    // The app's old name was the default heading; it follows the new one.
    // A heading the user typed is kept as it is.
    return config.brandText == oldDefaultBrand
        ? config.copyWith(brandText: WatermarkConfig.defaultBrand)
        : config;
  }

  /// The default heading before the app was renamed to Locaproof.
  static const String oldDefaultBrand = 'GPS CAMERA';

  Future<void> save(WatermarkConfig config) =>
      _storage.write(StorageKeys.watermarkConfig, config.toJson());

  /// Whether each capture also saves a watermarked copy. On by default.
  bool loadAutoWatermark() =>
      _storage.read<bool>(StorageKeys.autoWatermark) ?? true;

  Future<void> saveAutoWatermark(bool enabled) =>
      _storage.write(StorageKeys.autoWatermark, enabled);
}
