import 'package:gps_camera/features/location/models/location_snapshot.dart';

/// Sidecar data stored next to each photo as `<photo name>.json`.
class PhotoMetadata {
  const PhotoMetadata({
    required this.imageFileName,
    required this.capturedAt,
    required this.timeZoneOffset,
    required this.timeZoneName,
    required this.location,
    this.schemaVersion = currentSchemaVersion,
  });

  factory PhotoMetadata.create({
    required String imageFileName,
    required DateTime capturedAt,
    required LocationSnapshot location,
  }) {
    final local = capturedAt.toLocal();
    return PhotoMetadata(
      imageFileName: imageFileName,
      capturedAt: capturedAt.toUtc(),
      timeZoneOffset: local.timeZoneOffset,
      timeZoneName: local.timeZoneName,
      location: location,
    );
  }

  factory PhotoMetadata.fromJson(Map<String, dynamic> json) {
    return PhotoMetadata(
      schemaVersion: json['schemaVersion'] as int,
      imageFileName: json['imageFileName'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      timeZoneOffset: Duration(minutes: json['timeZoneOffsetMinutes'] as int),
      timeZoneName: json['timeZoneName'] as String,
      location: LocationSnapshot.fromJson(
        json['location'] as Map<String, dynamic>,
      ),
    );
  }

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String imageFileName;

  /// Capture time (UTC).
  final DateTime capturedAt;

  /// Device time zone at capture, so local time can be shown later.
  final Duration timeZoneOffset;
  final String timeZoneName;
  final LocationSnapshot location;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'imageFileName': imageFileName,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'timeZoneOffsetMinutes': timeZoneOffset.inMinutes,
    'timeZoneName': timeZoneName,
    'location': location.toJson(),
  };
}
