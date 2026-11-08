import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/models/capture_feedback.dart';
import 'package:gps_camera/features/camera/models/capture_post_processing.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/features/export/services/gallery_export_service.dart';
import 'package:gps_camera/features/gallery/services/gallery_scanner.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/place_info.dart';
import 'package:gps_camera/features/video/services/video_stamp_service.dart';
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
    this._gallery,
    this._imageSize = readImageSize,
    this._videoStamper,
  });

  /// Makes stamped copies of videos; found through GetX when null.
  final VideoStampService? _videoStamper;

  final PhotoStorageService _storage;
  final WatermarkRenderer _renderer;
  final WatermarkSettingsStore _settings;
  final PlaceLookup _placeFor;
  final MapGrabber _grabMap;
  final ImageSizeReader _imageSize;

  /// Copies the result to the phone gallery; null skips that step.
  final GalleryExportService? _gallery;

  @override
  Future<Uint8List?> grabMap() async {
    try {
      return await _grabMap();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CaptureFeedback?> process(SavedCapture saved, Uint8List? map) async {
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

    String? message;
    File? copy;
    var failed = false;
    if (_settings.loadAutoWatermark()) {
      (copy, message) = await _renderCopy(saved.photo, metadata, mapName, map);
      failed = copy == null;
    }

    final gallery = _gallery;
    if (gallery != null) {
      bool exported;
      try {
        exported = await gallery.exportCapture(
          original: saved.photo,
          watermarked: copy,
          metadata: metadata,
        );
      } catch (_) {
        exported = false;
      }
      if (!exported) {
        failed = true;
        message = message == null
            ? 'Not saved to phone gallery'.tr
            : '@message · not saved to phone gallery'.trParams({
                'message': message,
              });
      }
    }
    return message == null ? null : CaptureFeedback(message, isError: failed);
  }

  Future<(File?, String)> _renderCopy(
    File photo,
    PhotoMetadata metadata,
    String? mapName,
    Uint8List? map,
  ) async {
    if (metadata.isVideo) return _stampVideo(photo, metadata);
    try {
      final size = await _imageSize(photo.path);
      if (size == null) {
        return (null, 'Watermarked copy not saved: photo unreadable'.tr);
      }
      final result = await _renderer.render(
        original: photo,
        metadata: metadata,
        config: _settings.load(),
        imageSize: size,
        mapImage: mapName == null ? null : map,
        automatic: true,
      );
      return (result.output, 'Watermarked copy saved'.tr);
    } on WatermarkException catch (e) {
      return (
        null,
        'Watermarked copy not saved: @error'.trParams({'error': e.message}),
      );
    } catch (_) {
      return (null, 'Watermarked copy not saved'.tr);
    }
  }

  /// The stamped copy of a video, with the stamp live for every second.
  Future<(File?, String)> _stampVideo(
    File video,
    PhotoMetadata metadata,
  ) async {
    final stamper =
        _videoStamper ??
        (Get.isRegistered<VideoStampService>()
            ? Get.find<VideoStampService>()
            : null);
    if (stamper == null) return (null, 'Stamped video not saved'.tr);
    try {
      final result = await stamper.stamp(
        original: video,
        metadata: metadata,
        config: _settings.load(),
        automatic: true,
      );
      return (result.output, 'Stamped video saved'.tr);
    } on WatermarkException catch (e) {
      return (
        null,
        'Stamped video not saved: @error'.trParams({'error': e.message}),
      );
    } catch (_) {
      return (null, 'Stamped video not saved'.tr);
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
