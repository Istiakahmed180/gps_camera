import 'package:gps_camera/core/settings/display_format.dart';

/// Formats a capture time in the time zone it was taken in, not the
/// device's current zone.
abstract final class CaptureTimeFormatter {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Wall-clock time at the capture location, as a UTC-flagged value whose
  /// fields read as local time.
  static DateTime wallClock(DateTime capturedAt, Duration offset) =>
      capturedAt.toUtc().add(offset);

  /// `07 Nov 2026`
  static String date(DateTime wallClock) =>
      '${_two(wallClock.day)} ${_months[wallClock.month - 1]} '
      '${wallClock.year}';

  /// `10:02 AM`, or `10:02` / `22:02` when 24-hour time is chosen.
  static String time(DateTime wallClock, {bool? use24Hour}) {
    if (use24Hour ?? DisplayFormat.current.use24Hour) {
      return '${_two(wallClock.hour)}:${_two(wallClock.minute)}';
    }
    final hour = wallClock.hour % 12 == 0 ? 12 : wallClock.hour % 12;
    final period = wallClock.hour < 12 ? 'AM' : 'PM';
    return '${_two(hour)}:${_two(wallClock.minute)} $period';
  }

  /// `UTC+06:00`, `UTC-03:30`, or `UTC`.
  static String utcOffset(Duration offset) {
    if (offset == Duration.zero) return 'UTC';
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    return 'UTC$sign${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
  }

  /// `<1 s`, `45 s`, `12 min`, `3 h`
  static String age(Duration age) {
    if (age.inSeconds < 1) return '<1 s';
    if (age.inSeconds < 60) return '${age.inSeconds} s';
    if (age.inMinutes < 60) return '${age.inMinutes} min';
    return '${age.inHours} h';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
