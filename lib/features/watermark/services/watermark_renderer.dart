import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/models/watermark_record.dart';
import 'package:gps_camera/features/watermark/services/image_processor.dart';
import 'package:gps_camera/features/watermark/services/overlay_rasterizer.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';

class WatermarkException implements Exception {
  const WatermarkException(this.message);

  final String message;

  @override
  String toString() => 'WatermarkException: $message';
}

class WatermarkResult {
  const WatermarkResult({required this.output, required this.record});

  /// The new watermarked JPEG.
  final File output;

  /// JSON next to [output] linking it to its original and settings.
  final File record;
}

/// Produces a watermarked copy of an original photo. The original and its
/// metadata sidecar are only ever read.
class WatermarkRenderer {
  WatermarkRenderer(
    this._storage, {
    this._processor = const ImageProcessor(),
    this._rasterize = rasterizeWatermark,
    this._clock = DateTime.now,
  });

  final PhotoStorageService _storage;
  final ImageProcessor _processor;
  final OverlayRasterizer _rasterize;
  final DateTime Function() _clock;

  /// [imageSize] is the oriented size of [original], as reported by
  /// [ImageProcessor.loadPreview]. Throws [WatermarkException] on failure,
  /// leaving no partial output behind.
  Future<WatermarkResult> render({
    required File original,
    required PhotoMetadata metadata,
    required WatermarkConfig config,
    required Size imageSize,
    Uint8List? mapImage,
    bool automatic = false,
  }) async {
    if (_storage.isWatermarkedFile(original)) {
      throw const WatermarkException(
        'This is already a watermarked copy. Open its original instead.',
      );
    }
    final content = WatermarkContent.from(metadata, config);
    if (content.isEmpty) {
      throw const WatermarkException('Choose at least one detail to show.');
    }

    final map = mapImage == null ? null : await decodeMapImage(mapImage);
    final logoBytes = config.showLogo ? await _storage.readLogo() : null;
    final logo = logoBytes == null ? null : await decodeMapImage(logoBytes);
    final painter = WatermarkPainter(
      content: content,
      config: config,
      imageSize: imageSize,
      mapImage: map,
      logoImage: logo,
    );
    OverlayBitmap? overlay;
    try {
      overlay = await _rasterize(painter);
    } catch (e) {
      throw WatermarkException('The watermark could not be drawn: $e');
    } finally {
      painter.dispose();
      map?.dispose();
      logo?.dispose();
    }
    if (overlay == null) {
      throw const WatermarkException('The watermark could not be drawn.');
    }

    final File target;
    try {
      target = await _storage.reserveWatermarkedFile(original);
    } on FileSystemException catch (e) {
      throw WatermarkException('No space for the output file: ${e.message}');
    }

    final temp = File('${target.path}.tmp');
    try {
      await _processor.composeToFile(
        sourcePath: original.path,
        targetPath: temp.path,
        overlay: overlay,
        expectedWidth: imageSize.width.round(),
        expectedHeight: imageSize.height.round(),
      );
      await temp.rename(target.path);
      final record = await _storage.writeJsonAtomic(
        _storage.metadataFileFor(target),
        _record(
          original,
          target,
          imageSize,
          config,
          metadata,
          automatic,
        ).toJson(),
      );
      return WatermarkResult(output: target, record: record);
    } catch (e) {
      await _storage.releaseReservation(target);
      throw WatermarkException(switch (e) {
        ImageProcessingException(:final message) => message,
        FileSystemException(:final message) =>
          'The watermarked copy could not be saved: $message',
        _ => 'The watermarked copy could not be created: $e',
      });
    }
  }

  WatermarkRecord _record(
    File original,
    File output,
    Size imageSize,
    WatermarkConfig config,
    PhotoMetadata metadata,
    bool automatic,
  ) {
    String name(File f) => f.uri.pathSegments.last;
    return WatermarkRecord(
      outputFileName: name(output),
      sourceImageFileName: name(original),
      sourceMetadataFileName: name(_storage.metadataFileFor(original)),
      renderedAt: _clock().toUtc(),
      imageWidth: imageSize.width.round(),
      imageHeight: imageSize.height.round(),
      config: config,
      sourceMetadata: metadata,
      automatic: automatic,
    );
  }
}

/// Decodes a stored map snapshot; null if it is unreadable, so a damaged
/// map file never blocks a watermark.
Future<Image?> decodeMapImage(Uint8List bytes) async {
  try {
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  } catch (_) {
    return null;
  }
}
