import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:gps_camera/features/video/services/video_service.dart';
import 'package:gps_camera/features/video/services/video_stamp_service.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/services/capture_enricher.dart';
import 'package:gps_camera/features/export/services/gallery_export_service.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/location/models/place_info.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';

typedef PlaceDescriber = Future<PlaceInfo> Function(double lat, double lng);
typedef MapFetcher = Future<Uint8List?> Function(double lat, double lng);

class BackfillResult {
  const BackfillResult({
    this.updatedPhotos = 0,
    this.replacedCopies = 0,
    this.remaining = 0,
  });

  /// Originals that gained an address or map.
  final int updatedPhotos;

  /// Automatic watermarked copies made again with the new details.
  final int replacedCopies;

  /// Photos still missing details after this run.
  final int remaining;

  bool get changedAnything => updatedPhotos > 0;
}

/// Adds the address and map to photos taken without internet, once the
/// internet is back.
///
/// Only the sidecar's place and map are added; capture time, GPS values and
/// the original JPEG are never changed. Automatic watermarked copies that
/// were made without those details are made again and the old copy is
/// removed from the app. Copies made in the editor are never touched.
class DetailsBackfill {
  DetailsBackfill({
    required this._storage,
    required this._gallery,
    required this._describe,
    required this._renderer,
    this._fetchMap,
    this._export,
    this._imageSize = CaptureEnricher.readImageSize,
    this.maxPerRun = 20,
  });

  final PhotoStorageService _storage;
  final GalleryService _gallery;
  final PlaceDescriber _describe;
  final WatermarkRenderer _renderer;
  final MapFetcher? _fetchMap;
  final GalleryExportService? _export;
  final ImageSizeReader _imageSize;

  /// Caps network calls per run, to stay well inside free quotas.
  final int maxPerRun;

  /// Photos that got no address this session although the geocoder
  /// answered for others (e.g. a spot at sea). Not asked again until the
  /// app restarts.
  final Set<String> _noAddress = {};

  bool _running = false;

  /// True when [metadata] has GPS but lacks an address or (when maps are
  /// available) a map.
  bool needsDetails(PhotoMetadata? metadata) {
    if (metadata?.location.fix == null) return false;
    return _missingAddress(metadata!) || _missingMap(metadata);
  }

  bool _missingAddress(PhotoMetadata m) => m.place?.hasAddress != true;

  bool _missingMap(PhotoMetadata m) =>
      _fetchMap != null && m.mapImageFileName == null;

  Future<BackfillResult> run() async {
    if (_running) return const BackfillResult();
    _running = true;
    try {
      return await _run();
    } finally {
      _running = false;
    }
  }

  Future<BackfillResult> _run() async {
    final index = await _gallery.scan();
    final pending = [
      for (final photo in index.photos)
        if (photo.isOriginal &&
            needsDetails(photo.metadata) &&
            !(_noAddress.contains(photo.fileName) &&
                !_missingMap(photo.metadata!)))
          photo,
    ];

    var updated = 0;
    var replaced = 0;
    var failuresInARow = 0;
    for (final photo in pending.take(maxPerRun)) {
      final outcome = await _fill(photo, index.variantsOf(photo));
      if (outcome == null) {
        // Nothing came back: most likely offline. Try again later.
        if (++failuresInARow >= 2) break;
        continue;
      }
      failuresInARow = 0;
      updated++;
      replaced += outcome;
    }
    final remaining = (await _gallery.scan()).photos
        .where((p) => p.isOriginal && needsDetails(p.metadata))
        .length;
    return BackfillResult(
      updatedPhotos: updated,
      replacedCopies: replaced,
      remaining: remaining,
    );
  }

  /// Returns the number of copies replaced, or null when nothing new was
  /// found for [photo].
  Future<int?> _fill(GalleryPhoto photo, List<GalleryPhoto> variants) async {
    final metadata = photo.metadata!;
    final fix = metadata.location.fix!;
    final original = photo.file;

    PlaceInfo? place;
    if (_missingAddress(metadata) && !_noAddress.contains(photo.fileName)) {
      try {
        final found = await _describe(fix.latitude, fix.longitude);
        if (found.hasAddress) place = found;
      } catch (_) {
        place = null;
      }
    }

    Uint8List? map;
    String? mapName;
    final fetchMap = _fetchMap;
    if (fetchMap != null && metadata.mapImageFileName == null) {
      try {
        map = await fetchMap(fix.latitude, fix.longitude);
        if (map != null) {
          mapName = (await _storage.saveMapImage(
            original,
            map,
          )).uri.pathSegments.last;
        }
      } catch (_) {
        map = null;
        mapName = null;
      }
    }

    if (place == null && mapName == null) return null;
    if (place == null && _missingAddress(metadata)) {
      // The map service answered, so the phone is online; the geocoder
      // simply has no address here.
      _noAddress.add(photo.fileName);
    }

    final next = metadata.withPlace(place: place, mapImageFileName: mapName);
    try {
      await _storage.saveMetadata(original, next.toJson());
    } catch (_) {
      return null;
    }

    map ??= await CaptureEnricher.storedMap(_storage, original, next);
    var replaced = 0;
    for (final copy in variants) {
      if (await _replaceCopy(original, copy, next, map, place != null)) {
        replaced++;
      }
    }
    return replaced;
  }

  Future<bool> _replaceCopy(
    File original,
    GalleryPhoto copy,
    PhotoMetadata metadata,
    Uint8List? map,
    bool gotAddress,
  ) async {
    final record = copy.record;
    if (record == null || !record.automatic) return false;
    final before = record.sourceMetadata;
    final config = record.config;
    final addsAddress =
        gotAddress && config.showAddress && before?.place?.hasAddress != true;
    final addsMap =
        map != null &&
        config.template.showsMap &&
        before?.mapImageFileName == null;
    if (!addsAddress && !addsMap) return false;

    try {
      final WatermarkResult result;
      if (copy.isVideo) {
        // Videos are stamped again with the new details, live as before.
        final stamper = Get.isRegistered<VideoStampService>()
            ? Get.find<VideoStampService>()
            : null;
        // Waits for its turn behind any other video being stamped.
        if (stamper == null) return false;
        result = await stamper.stamp(
          original: original,
          metadata: metadata,
          config: config,
          automatic: true,
        );
      } else {
        final size = await _imageSize(original.path);
        if (size == null) return false;
        result = await _renderer.render(
          original: original,
          metadata: metadata,
          config: config,
          imageSize: Size(size.width, size.height),
          mapImage: metadata.mapImageFileName == null ? null : map,
          automatic: true,
        );
      }
      try {
        await _export?.exportEdited(
          result.output,
          takenAt: metadata.capturedAt,
        );
      } catch (_) {}
      // The new copy is saved; only now remove the incomplete one.
      if (copy.isVideo && Get.isRegistered<VideoService>()) {
        await Get.find<VideoService>().forgetThumbnail(copy.path);
      }
      for (final file in [copy.file, _storage.metadataFileFor(copy.file)]) {
        try {
          await file.delete();
        } on FileSystemException {
          // A leftover old copy is harmless; it stays in the gallery.
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
