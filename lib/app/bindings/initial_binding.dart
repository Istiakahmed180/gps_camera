import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/database/database_service.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/core/services/theme_service.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

/// App-wide services that live for the whole session.
/// Requires `GetStorage.init()` to have completed.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    final storage = Get.put(StorageService(GetStorage()), permanent: true);
    Get.put(ThemeService(storage), permanent: true);
    Get.lazyPut(PermissionService.new, fenix: true);
    Get.lazyPut(PhotoStorageService.new, fenix: true);
    Get.lazyPut(ShareService.new, fenix: true);

    // The database opens lazily on a background isolate at the first query,
    // so registering it here never delays the first screen.
    final database = Get.put(DatabaseService(), permanent: true);
    Get.lazyPut(() => ProjectRepository(database.db), fenix: true);
    Get.lazyPut(
      () => GalleryService(Get.find<PhotoStorageService>()),
      fenix: true,
    );
  }
}
