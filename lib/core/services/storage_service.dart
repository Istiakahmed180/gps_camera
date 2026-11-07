import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Key-value store for lightweight settings. Structured data
/// (projects, photos) will live in a database introduced later.
class StorageService extends GetxService {
  StorageService(this._box);

  final GetStorage _box;

  T? read<T>(String key) => _box.read<T>(key);

  Future<void> write(String key, Object value) => _box.write(key, value);

  Future<void> remove(String key) => _box.remove(key);
}
