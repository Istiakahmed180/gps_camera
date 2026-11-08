import 'dart:io';

import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/services/capture_saver.dart';
import 'package:gps_camera/features/export/services/gallery_export_service.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/video/services/video_stamp_service.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';

/// Finishes video work that Android interrupted by closing the app:
/// a recording that stopped but was not saved yet, and automatic stamped
/// copies that were never made. Runs once when the app starts.
class VideoRecovery {
  VideoRecovery({
    required this._storage,
    required this._saver,
    required this._stamper,
    required this._gallery,
    required this._autoStamp,
    required this._config,
    required this._temporaryDirectory,
    this._export,
  });

  final PhotoStorageService _storage;
  final CaptureSaver _saver;
  final VideoStampService _stamper;
  final GalleryService _gallery;
  final bool Function() _autoStamp;
  final WatermarkConfig Function() _config;
  final Future<Directory> Function() _temporaryDirectory;
  final GalleryExportService? _export;

  /// Returns true when an interrupted recording was saved.
  Future<bool> run() async {
    final recovered = await _recoverRecording();
    await _stampPending();
    return recovered;
  }

  Future<bool> _recoverRecording() async {
    // A recording in progress right now is not an interrupted one.
    if (_stamper.hold.value) return false;
    return await _saver.recoverRecording(
          temporaryDirectory: _temporaryDirectory,
        ) !=
        null;
  }

  /// Makes the automatic stamped copies that were never made.
  Future<void> _stampPending() async {
    final index = await _gallery.scan();
    for (final photo in index.photos) {
      final metadata = photo.metadata;
      final video = metadata?.video;
      if (!photo.isOriginal || metadata == null || video == null) continue;
      if (!video.stampPending) continue;
      if (!_autoStamp() || index.variantsOf(photo).isNotEmpty) {
        // Not wanted, or already made: just clear the mark.
        try {
          await _storage.saveMetadata(
            photo.file,
            metadata.withVideo(video.withStampPending(false)).toJson(),
          );
        } catch (_) {}
        continue;
      }
      try {
        final result = await _stamper.stamp(
          original: photo.file,
          metadata: metadata,
          config: _config(),
          automatic: true,
        );
        await _export?.exportCapture(
          original: photo.file,
          watermarked: result.output,
          metadata: metadata,
        );
      } catch (_) {
        // Tried again the next time the app starts.
      }
    }
  }
}
