import 'package:gps_camera/features/camera/models/video_details.dart';
import 'package:gps_camera/features/location/models/camera_direction.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/models/place_info.dart';

/// Sidecar data stored next to each photo as `<photo name>.json`.
class PhotoMetadata {
  const PhotoMetadata({
    required this.imageFileName,
    required this.capturedAt,
    required this.timeZoneOffset,
    required this.timeZoneName,
    required this.location,
    this.place,
    this.mapImageFileName,
    this.note,
    this.direction,
    this.video,
    this.schemaVersion = currentSchemaVersion,
  });

  /// Longest note kept; longer text is cut.
  static const int maxNoteLength = 300;

  /// Trims [value], cuts it to [maxNoteLength] and turns blank into null.
  static String? cleanNote(String? value) {
    final text = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text == null || text.isEmpty) return null;
    return text.length > maxNoteLength
        ? text.substring(0, maxNoteLength).trimRight()
        : text;
  }

  factory PhotoMetadata.create({
    required String imageFileName,
    required DateTime capturedAt,
    required LocationSnapshot location,
    String? note,
    CameraDirection? direction,
    VideoDetails? video,
  }) {
    final local = capturedAt.toLocal();
    return PhotoMetadata(
      imageFileName: imageFileName,
      capturedAt: capturedAt.toUtc(),
      timeZoneOffset: local.timeZoneOffset,
      timeZoneName: local.timeZoneName,
      location: location,
      note: cleanNote(note),
      direction: direction,
      video: video,
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
      place: switch (json['place']) {
        final Map<String, dynamic> place => PlaceInfo.fromJson(place),
        _ => null,
      },
      mapImageFileName: json['mapImageFileName'] as String?,
      note: cleanNote(json['note'] as String?),
      direction: switch (json['direction']) {
        final Map<String, dynamic> d => CameraDirection.fromJson(d),
        _ => null,
      },
      video: switch (json['video']) {
        final Map<String, dynamic> v => VideoDetails.fromJson(v),
        _ => null,
      },
    );
  }

  /// Adds the looked-up place and map image. Capture time and GPS values
  /// are never changed.
  PhotoMetadata withPlace({PlaceInfo? place, String? mapImageFileName}) =>
      PhotoMetadata(
        imageFileName: imageFileName,
        capturedAt: capturedAt,
        timeZoneOffset: timeZoneOffset,
        timeZoneName: timeZoneName,
        location: location,
        place: place ?? this.place,
        mapImageFileName: mapImageFileName ?? this.mapImageFileName,
        note: note,
        direction: direction,
        video: video,
      );

  /// The same photo with a new note (null or blank removes it). Nothing
  /// else changes.
  PhotoMetadata withNote(String? value) => PhotoMetadata(
    schemaVersion: schemaVersion,
    imageFileName: imageFileName,
    capturedAt: capturedAt,
    timeZoneOffset: timeZoneOffset,
    timeZoneName: timeZoneName,
    location: location,
    place: place,
    mapImageFileName: mapImageFileName,
    note: cleanNote(value),
    direction: direction,
    video: video,
  );

  /// The same capture at [atMs] into its video: the time moves on, and the
  /// location and direction recorded at that moment replace the start ones.
  /// Used to draw the live stamp.
  PhotoMetadata atVideoTime(int atMs) {
    final point = video?.pointAt(atMs);
    return PhotoMetadata(
      schemaVersion: schemaVersion,
      imageFileName: imageFileName,
      capturedAt: capturedAt.add(Duration(milliseconds: atMs)),
      timeZoneOffset: timeZoneOffset,
      timeZoneName: timeZoneName,
      location: point?.location ?? location,
      place: place,
      mapImageFileName: mapImageFileName,
      note: note,
      direction: point?.direction ?? direction,
      video: video,
    );
  }

  /// The same capture with its video details filled in.
  PhotoMetadata withVideo(VideoDetails value) => PhotoMetadata(
    schemaVersion: schemaVersion,
    imageFileName: imageFileName,
    capturedAt: capturedAt,
    timeZoneOffset: timeZoneOffset,
    timeZoneName: timeZoneName,
    location: location,
    place: place,
    mapImageFileName: mapImageFileName,
    note: note,
    direction: direction,
    video: value,
  );

  /// 2 adds [place] and [mapImageFileName]; version 1 files still load.
  static const int currentSchemaVersion = 2;

  final int schemaVersion;
  final String imageFileName;

  /// Capture time (UTC).
  final DateTime capturedAt;

  /// Device time zone at capture, so local time can be shown later.
  final Duration timeZoneOffset;
  final String timeZoneName;
  final LocationSnapshot location;

  /// Address and Plus Code for the capture location, when looked up.
  final PlaceInfo? place;

  /// File in `GPSCamera/Maps/` with the map shown at capture, if any.
  final String? mapImageFileName;

  /// The user's own description of the photo, e.g. "Crack on pillar 3".
  final String? note;

  /// Which way the camera faced, from the compass; null when unknown.
  final CameraDirection? direction;

  /// For videos: length, size and the per-second location track. The
  /// other fields describe the moment recording started.
  final VideoDetails? video;

  bool get isVideo => video != null || isVideoPath(imageFileName);

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'imageFileName': imageFileName,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'timeZoneOffsetMinutes': timeZoneOffset.inMinutes,
    'timeZoneName': timeZoneName,
    'location': location.toJson(),
    'place': place?.toJson(),
    'mapImageFileName': mapImageFileName,
    // Written only when set, so older files stay unchanged until edited.
    if (note != null) 'note': note,
    if (direction != null) 'direction': direction!.toJson(),
    if (video != null) 'video': video!.toJson(),
  };
}
