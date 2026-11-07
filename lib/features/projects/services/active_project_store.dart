import 'package:gps_camera/core/constants/storage_keys.dart';
import 'package:gps_camera/core/services/storage_service.dart';

/// Remembers the camera's active project across app restarts.
class ActiveProjectStore {
  ActiveProjectStore(this._storage);

  final StorageService _storage;

  String? load() => _storage.read<String>(StorageKeys.activeProjectId);

  Future<void> save(String? projectId) => projectId == null
      ? _storage.remove(StorageKeys.activeProjectId)
      : _storage.write(StorageKeys.activeProjectId, projectId);
}
