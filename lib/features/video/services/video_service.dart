import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';

/// Length and size of a video file, as displayed.
class VideoInfo {
  const VideoInfo({
    required this.durationMs,
    required this.width,
    required this.height,
    required this.hasAudio,
  });

  final int durationMs;
  final int width;
  final int height;
  final bool hasAudio;
}

/// One stamp image, shown from [fromMs] until the next one.
class StampFrame {
  const StampFrame({
    required this.fromMs,
    required this.path,
    required this.left,
    required this.top,
  });

  final int fromMs;

  /// PNG of the stamp area.
  final String path;

  /// Where the stamp area sits in the frame, in pixels.
  final int left;
  final int top;

  Map<String, Object> toMap() => {
    'fromMs': fromMs,
    'path': path,
    'left': left,
    'top': top,
  };
}

class VideoException implements Exception {
  const VideoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Video helpers done natively: size and length, thumbnails, and burning
/// the location stamp into a copy. Originals are only ever read.
class VideoService extends GetxService {
  VideoService(this._storage, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('co.tdevs.gps_camera/video') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress') {
        _onProgress?.call((call.arguments as num).toDouble().clamp(0, 1));
      }
    });
  }

  final PhotoStorageService _storage;
  final MethodChannel _channel;
  final Map<String, Future<File?>> _thumbnails = {};
  void Function(double progress)? _onProgress;

  Future<VideoInfo?> info(String path) async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('info', {
        'path': path,
      });
      if (map == null) return null;
      return VideoInfo(
        durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
        width: (map['width'] as num?)?.toInt() ?? 0,
        height: (map['height'] as num?)?.toInt() ?? 0,
        hasAudio: map['hasAudio'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  /// A frame of the video at [videoPath], made once and kept in
  /// `Thumbnails/`. Null when it cannot be made.
  Future<File?> thumbnail(String videoPath) =>
      _thumbnails[videoPath] ??= _makeThumbnail(videoPath).then((file) {
        if (file == null) _thumbnails.remove(videoPath);
        return file;
      });

  Future<File?> _makeThumbnail(String videoPath) async {
    try {
      final target = await _storage.thumbnailFileFor(videoPath);
      final video = File(videoPath);
      if (!await video.exists()) return null;
      // Kept only while it is newer than the video it shows.
      if (await target.exists() &&
          await target.length() > 0 &&
          !(await target.lastModified()).isBefore(await video.lastModified())) {
        return target;
      }
      await _channel.invokeMethod<void>('thumbnail', {
        'path': videoPath,
        'output': target.path,
        'atMs': 500,
        'maxSide': 720,
      });
      if (!await target.exists()) return null;
      // An older frame with this name may still be in the image cache.
      await FileImage(target).evict();
      return target;
    } catch (_) {
      return null;
    }
  }

  /// Forgets and deletes the thumbnail of a deleted video.
  Future<void> forgetThumbnail(String videoPath) async {
    unawaited(_thumbnails.remove(videoPath));
    try {
      final file = await _storage.thumbnailFileFor(videoPath);
      await FileImage(file).evict();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Writes a copy of [input] to [output] with [frames] drawn on it, in a
  /// [width] x [height] (as displayed) frame.
  Future<void> stamp({
    required String input,
    required String output,
    required int width,
    required int height,
    required List<StampFrame> frames,
    void Function(double progress)? onProgress,
  }) async {
    _onProgress = onProgress;
    try {
      await _channel.invokeMethod<void>('stamp', {
        'input': input,
        'output': output,
        'width': width,
        'height': height,
        'frames': [for (final f in frames) f.toMap()],
      });
    } on PlatformException catch (e) {
      throw VideoException(e.message ?? e.code);
    } finally {
      _onProgress = null;
    }
  }
}
