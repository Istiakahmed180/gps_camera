import 'dart:io';

import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/watermark/controllers/watermark_controller.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';

/// Expects the original photo's path as the route argument.
class WatermarkBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() {
      final storage = Get.find<PhotoStorageService>();
      return WatermarkController(
        photo: File(Get.arguments as String),
        storage: storage,
        renderer: WatermarkRenderer(storage),
        settings: WatermarkSettingsStore(Get.find<StorageService>()),
      );
    });
  }
}
