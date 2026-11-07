import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/core/services/theme_service.dart';

/// App-wide services that live for the whole session.
/// Requires `GetStorage.init()` to have completed.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    final storage = Get.put(StorageService(GetStorage()), permanent: true);
    Get.put(ThemeService(storage), permanent: true);
    Get.lazyPut(PermissionService.new, fenix: true);
    Get.lazyPut(PhotoStorageService.new, fenix: true);
  }
}
