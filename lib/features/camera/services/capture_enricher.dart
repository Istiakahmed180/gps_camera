import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/models/capture_post_processing.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/features/gallery/services/gallery_scanner.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/place_info.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';

typedef PlaceLookup = Future<PlaceInfo?> Function(LocationFix? fix);
typedef MapGrabber = Future<Uint8List?> Function();
typedef ImageSizeReader = Future<Size?> Function(String path);

/// Adds the capture's place and map to its metadata, then saves the
/// automatic watermarked copy. The original JPEG is never modified, and
/// capture time and GPS values in the sidecar are kept exactly.
class CaptureEnricher implements CapturePostProcessor {
  CaptureEnricher({
    required this._storage,
    required this._renderer,
    required this._settings,
    required this._placeFor,
    required this._grabMap,
    this._imageSize = readImageSize,
  });

  final PhotoStorageService _storage;
  final WatermarkRenderer _renderer;
  final WatermarkSettingsStore _settings;
  final PlaceLookup _placeFor;
  final MapGrabber _grabMap;
  final ImageSizeReader _imageSize;

  @override
  Future<Uint8List?> grabMap() async {
    try {
      return await _grabMap();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> process(SavedCapture saved, Uint8List? map) async {
    final fix = saved.metadata.location.fix;
    PlaceInfo? place;
    try {
      place = await _placeFor(fix);
    } catch (_) {
      place = null;
    }

    String? mapName;
    if (map != null && fix != null) {
      try {
        mapName = (await _storage.saveMapImage(
          saved.photo,
          map,
        )).uri.pathSegments.last;
      } catch (_) {
        mapName = null;
      }
    }

    var metadata = saved.metadata;
    if (place != null || mapName != null) {
      metadata = metadata.withPlace(place: place, mapImageFileName: mapName);
      if (saved.metadataFile != null) {
        try {
          await _storage.saveMetadata(saved.photo, metadata.toJson());
        } catch (_) {
          // The capture metadata already on disk stays valid.
        }
      }
    }

    if (!_settings.loadAutoWatermark()) return null;
    try {
      final size = await _imageSize(saved.photo.path);
      if (size == null) return 'Watermarked copy not saved: photo unreadable';
      await _renderer.render(
        original: saved.photo,
        metadata: metadata,
        config: _settings.load(),
        imageSize: size,
        mapImage: mapName == null ? null : map,
      );
      return 'Watermarked copy saved';
    } on WatermarkException catch (e) {
      return 'Watermarked copy not saved: ${e.message}';
    } catch (_) {
      return 'Watermarked copy not saved';
    }
  }

  /// Oriented size from the JPEG header, read off the UI thread.
  static Future<Size?> readImageSize(String path) async {
    final dims = await Isolate.run(() => readJpegDimensions(path));
    return dims == null
        ? null
        : Size(dims.width.toDouble(), dims.height.toDouble());
  }

  /// Reads the stored map image of a photo, for the editor.
  static Future<Uint8List?> storedMap(
    PhotoStorageService storage,
    File photo,
    PhotoMetadata metadata,
  ) async {
    if (metadata.mapImageFileName == null) return null;
    try {
      final file = await storage.mapImageFor(photo);
      return await file.exists() ? await file.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }
}
