import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/export/services/gallery_export_service.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/location/services/details_backfill.dart';
import 'package:gps_camera/features/location/services/details_backfill_scheduler.dart';
import 'package:gps_camera/features/location/services/map_cache.dart';
import 'package:gps_camera/features/location/services/place_service.dart';
import 'package:gps_camera/features/location/services/static_map_service.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';

/// Work that runs while the app is open, outside any screen. Kept out of
/// [InitialBinding] so widget tests do not start timers.
abstract final class BackgroundServices {
  static Future<void> start() async {
    String? key;
    try {
      key = await const MethodChannel('co.tdevs.gps_camera/native')
          .invokeMethod<String>('mapKey');
    } catch (_) {
      key = null;
    }
    final maps = key == null || key.isEmpty
        ? null
        : StaticMapService(key, cache: Get.find<MapCache>());

    final storage = Get.find<PhotoStorageService>();
    final places = PlaceService();
    Get.put(
      DetailsBackfillScheduler(
        DetailsBackfill(
          storage: storage,
          gallery: Get.find<GalleryService>(),
          describe: places.describe,
          renderer: WatermarkRenderer(storage),
          fetchMap: maps?.fetch,
          export: Get.find<GalleryExportService>(),
        ),
      ),
      permanent: true,
    );
  }
}
