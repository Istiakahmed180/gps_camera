import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/video/services/video_service.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/models/watermark_record.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';
import 'package:path_provider/path_provider.dart';

/// Makes the stamped copy of a video: the location stamp is drawn for every
/// second (time ticking, location and direction as recorded at that moment)
/// and burned into a new MP4 in `Watermarked/`. The original video is only
/// read. One video at a time.
class VideoStampService extends GetxService {
  VideoStampService(
    this._storage,
    this._video, {
    Future<Directory> Function()? workDirectory,
    DateTime Function()? clock,
  }) : _workDirectory = workDirectory ?? getTemporaryDirectory,
       _clock = clock ?? DateTime.now;

  final PhotoStorageService _storage;
  final VideoService _video;
  final Future<Directory> Function() _workDirectory;
  final DateTime Function() _clock;

  /// 0 to 1 while a video is being stamped, null otherwise.
  final Rxn<double> progress = Rxn<double>();

  /// The original being stamped, if any.
  final RxnString busyWith = RxnString();

  bool get isBusy => busyWith.value != null;

  /// True while a video is recording; queued stamps wait until it ends so
  /// they don't compete with the camera for the video encoder.
  final RxBool hold = false.obs;

  Future<void> _queue = Future<void>.value();

  /// Drawing the stamp images is this share of the progress bar.
  static const double _drawShare = 0.25;

  /// Stamps [original] with [config]. Videos are stamped one at a time, in
  /// the order asked; this waits for its turn. Throws [WatermarkException]
  /// on failure, leaving no partial output behind.
  Future<WatermarkResult> stamp({
    required File original,
    required PhotoMetadata metadata,
    required WatermarkConfig config,
    bool automatic = false,
  }) {
    final run = _queue.then((_) async {
      while (hold.value) {
        await hold.stream.firstWhere((held) => !held);
      }
      return _stamp(original, metadata, config, automatic);
    });
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<WatermarkResult> _stamp(
    File original,
    PhotoMetadata metadata,
    WatermarkConfig config,
    bool automatic,
  ) async {
    if (_storage.isWatermarkedFile(original)) {
      throw const WatermarkException(
        'This is already a stamped copy. Open its original instead.',
      );
    }
    if (!await original.exists()) {
      throw const WatermarkException('The video no longer exists.');
    }
    if (WatermarkContent.from(metadata, config).isEmpty) {
      throw const WatermarkException('Choose at least one detail to show.');
    }

    busyWith.value = original.path;
    progress.value = 0;
    Directory? work;
    File? target;
    try {
      // Sizes saved as 0 (the video could not be read then) are read again.
      final details = metadata.video;
      final known = details != null && details.width > 0 && details.height > 0;
      final info = known ? null : await _video.info(original.path);
      final width = known ? details.width : info?.width ?? 0;
      final height = known ? details.height : info?.height ?? 0;
      final durationMs = details != null && details.durationMs > 0
          ? details.durationMs
          : info?.durationMs ?? 0;
      if (width <= 0 || height <= 0) {
        throw const WatermarkException('The video could not be read.');
      }

      work = await (await _workDirectory()).createTemp('video_stamp_');
      final frames = await _drawFrames(
        work,
        metadata,
        config,
        ui.Size(width.toDouble(), height.toDouble()),
        durationMs,
        await _storage.mapImageFor(original),
      );

      try {
        target = await _storage.reserveWatermarkedFile(original);
      } on FileSystemException catch (e) {
        throw WatermarkException('No space for the output file: ${e.message}');
      }
      await _video.stamp(
        input: original.path,
        output: target.path,
        width: width,
        height: height,
        frames: frames,
        onProgress: (p) => progress.value = _drawShare + p * (1 - _drawShare),
      );
      if (!await target.exists() || await target.length() == 0) {
        throw const WatermarkException('The stamped video was not written.');
      }
      final record = await _storage.writeJsonAtomic(
        _storage.metadataFileFor(target),
        WatermarkRecord(
          outputFileName: target.uri.pathSegments.last,
          sourceImageFileName: original.uri.pathSegments.last,
          sourceMetadataFileName: _storage
              .metadataFileFor(original)
              .uri
              .pathSegments
              .last,
          renderedAt: _clock().toUtc(),
          imageWidth: width,
          imageHeight: height,
          config: config,
          sourceMetadata: metadata,
          automatic: automatic,
        ).toJson(),
      );
      // The automatic copy now exists; recovery no longer needs to make it.
      final video = metadata.video;
      if (video != null && video.stampPending) {
        try {
          await _storage.saveMetadata(
            original,
            metadata.withVideo(video.withStampPending(false)).toJson(),
          );
        } catch (_) {}
      }
      return WatermarkResult(output: target, record: record);
    } catch (e) {
      if (target != null) await _storage.releaseReservation(target);
      if (e is WatermarkException) rethrow;
      throw WatermarkException(switch (e) {
        VideoException(:final message) =>
          'The stamped video could not be made: $message',
        FileSystemException(:final message) =>
          'The stamped video could not be saved: $message',
        _ => 'The stamped video could not be made: $e',
      });
    } finally {
      busyWith.value = null;
      progress.value = null;
      if (work != null) {
        try {
          await work.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// One PNG of the stamp area per second, skipping seconds whose stamp
  /// reads the same as the one before.
  Future<List<StampFrame>> _drawFrames(
    Directory work,
    PhotoMetadata metadata,
    WatermarkConfig config,
    ui.Size size,
    int durationMs,
    File mapFile,
  ) async {
    final map = await mapFile.exists()
        ? await decodeMapImage(await mapFile.readAsBytes())
        : null;
    final logoBytes = config.showLogo ? await _storage.readLogo() : null;
    final logo = logoBytes == null ? null : await decodeMapImage(logoBytes);
    final seconds = math.max(1, (durationMs / 1000).ceil());
    final frames = <StampFrame>[];
    String? previous;
    try {
      for (var s = 0; s < seconds; s++) {
        final content = WatermarkContent.from(
          metadata.atVideoTime(s * 1000),
          config,
        );
        // Unchanged since the last second: the last image stays up.
        if (content.signature != previous) {
          final painter = WatermarkPainter(
            content: content,
            config: config,
            imageSize: size,
            mapImage: map,
            logoImage: logo,
          );
          try {
            final drawn = await _rasterizePng(painter);
            if (drawn != null) {
              previous = content.signature;
              final file = File('${work.path}/stamp_$s.png');
              await file.writeAsBytes(drawn.$1);
              frames.add(
                StampFrame(
                  fromMs: s * 1000,
                  path: file.path,
                  left: drawn.$2,
                  top: drawn.$3,
                ),
              );
            }
          } finally {
            painter.dispose();
          }
        }
        progress.value = _drawShare * (s + 1) / seconds;
      }
    } finally {
      map?.dispose();
      logo?.dispose();
    }
    return frames;
  }

  /// The stamp area as a PNG, with its top-left corner in the frame.
  static Future<(Uint8List, int, int)?> _rasterizePng(
    WatermarkPainter painter,
  ) async {
    final bounds = painter.bounds;
    if (bounds.isEmpty) return null;
    final left = math.max(0, bounds.left.floor());
    final top = math.max(0, bounds.top.floor());
    final right = math.min(
      painter.imageSize.width.floor(),
      bounds.right.ceil(),
    );
    final bottom = math.min(
      painter.imageSize.height.floor(),
      bounds.bottom.ceil(),
    );
    if (right <= left || bottom <= top) return null;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..translate(-left.toDouble(), -top.toDouble());
    painter.paint(canvas);
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(right - left, bottom - top);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      return (data.buffer.asUint8List(), left, top);
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }
}
