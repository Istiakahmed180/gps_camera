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
    return saved == null
        ? const WatermarkConfig()
        : WatermarkConfig.fromJson(saved);
  }

  Future<void> save(WatermarkConfig config) =>
      _storage.write(StorageKeys.watermarkConfig, config.toJson());
}
