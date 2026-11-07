import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/watermark/utils/capture_time_formatter.dart';

abstract final class PhotoInfoFormatter {
  /// `07 Nov 2026 · 10:21 AM` in the capture's own time zone.
  static String captureShort(PhotoMetadata metadata) {
    final local = CaptureTimeFormatter.wallClock(
      metadata.capturedAt,
      metadata.timeZoneOffset,
    );
    return '${CaptureTimeFormatter.date(local)} · '
        '${CaptureTimeFormatter.time(local)}';
  }

  /// (`07 Nov 2026`, `10:21 AM`) in the capture's own time zone.
  static (String, String) captureParts(PhotoMetadata metadata) {
    final local = CaptureTimeFormatter.wallClock(
      metadata.capturedAt,
      metadata.timeZoneOffset,
    );
    return (CaptureTimeFormatter.date(local), CaptureTimeFormatter.time(local));
  }

  /// `07 Nov 2026 · 10:21 AM (UTC+06:00)`
  static String captureFull(PhotoMetadata metadata) =>
      '${captureShort(metadata)} '
      '(${CaptureTimeFormatter.utcOffset(metadata.timeZoneOffset)})';

  /// A UTC instant shown in the device's current zone.
  static String instant(DateTime time) {
    final local = time.toLocal();
    final wall = CaptureTimeFormatter.wallClock(local, local.timeZoneOffset);
    return '${CaptureTimeFormatter.date(wall)} · '
        '${CaptureTimeFormatter.time(wall)}';
  }

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// A stored measurement with up to [maxDecimals], trailing zeros removed,
  /// so the reported value is shown rather than a rounded summary.
  static String measured(double value, {int maxDecimals = 3}) {
    var text = value.toStringAsFixed(maxDecimals);
    if (text.contains('.')) {
      text = text
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return text.startsWith('-') ? '−${text.substring(1)}' : text;
  }
}
