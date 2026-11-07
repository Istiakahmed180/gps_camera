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
  }) {
    final local = capturedAt.toLocal();
    return PhotoMetadata(
      imageFileName: imageFileName,
      capturedAt: capturedAt.toUtc(),
      timeZoneOffset: local.timeZoneOffset,
      timeZoneName: local.timeZoneName,
      location: location,
      note: cleanNote(note),
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
  };
}
