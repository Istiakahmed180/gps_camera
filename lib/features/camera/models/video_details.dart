import 'package:gps_camera/features/location/models/camera_direction.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';

/// Whether [path] is a video file this app records.
bool isVideoPath(String path) => path.toLowerCase().endsWith('.mp4');

/// Where the camera was and which way it faced at one moment of a video.
class VideoTrackPoint {
  const VideoTrackPoint({required this.atMs, this.location, this.direction});

  factory VideoTrackPoint.fromJson(Map<String, dynamic> json) =>
      VideoTrackPoint(
        atMs: json['atMs'] as int,
        location: switch (json['location']) {
          final Map<String, dynamic> l => LocationSnapshot.fromJson(l),
          _ => null,
        },
        direction: switch (json['direction']) {
          final Map<String, dynamic> d => CameraDirection.fromJson(d),
          _ => null,
        },
      );

  /// Time since recording started.
  final int atMs;

  /// The location as known at that moment: current, last known (with its
  /// age) or unavailable, exactly as a photo would record it.
  final LocationSnapshot? location;
  final CameraDirection? direction;

  Map<String, dynamic> toJson() => {
    'atMs': atMs,
    if (location != null) 'location': location!.toJson(),
    if (direction != null) 'direction': direction!.toJson(),
  };
}

/// What a video's sidecar adds to the photo metadata: its length and size,
/// and the location recorded every second while filming.
class VideoDetails {
  const VideoDetails({
    required this.durationMs,
    required this.width,
    required this.height,
    required this.hasAudio,
    this.track = const [],
    this.stampPending = false,
  });

  factory VideoDetails.fromJson(Map<String, dynamic> json) => VideoDetails(
    durationMs: json['durationMs'] as int,
    width: json['width'] as int,
    height: json['height'] as int,
    hasAudio: json['hasAudio'] as bool? ?? false,
    track: [
      for (final p in (json['track'] as List?) ?? const [])
        VideoTrackPoint.fromJson(p as Map<String, dynamic>),
    ],
    stampPending: json['stampPending'] as bool? ?? false,
  );

  final int durationMs;

  /// As displayed (rotation applied).
  final int width;
  final int height;
  final bool hasAudio;

  /// One point per second, in time order.
  final List<VideoTrackPoint> track;

  /// The automatic stamped copy has not been made yet, e.g. because
  /// Android closed the app first. It is made the next time the app runs.
  final bool stampPending;

  VideoDetails withStampPending(bool value) => VideoDetails(
    durationMs: durationMs,
    width: width,
    height: height,
    hasAudio: hasAudio,
    track: track,
    stampPending: value,
  );

  Duration get duration => Duration(milliseconds: durationMs);

  /// The newest point at or before [atMs]; null before the first.
  VideoTrackPoint? pointAt(int atMs) {
    VideoTrackPoint? found;
    for (final p in track) {
      if (p.atMs > atMs) break;
      found = p;
    }
    return found;
  }

  Map<String, dynamic> toJson() => {
    'durationMs': durationMs,
    'width': width,
    'height': height,
    'hasAudio': hasAudio,
    'track': [for (final p in track) p.toJson()],
    if (stampPending) 'stampPending': true,
  };
}

/// `0:42`, `12:05` or `1:02:03`.
String formatVideoDuration(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}
