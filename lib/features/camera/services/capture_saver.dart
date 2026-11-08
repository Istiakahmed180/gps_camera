import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/camera/models/video_details.dart';
import 'package:gps_camera/features/location/models/camera_direction.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/video/services/video_service.dart';

class SavedCapture {
  const SavedCapture({
    required this.photo,
    required this.metadata,
    this.metadataFile,
  });

  final File photo;
  final PhotoMetadata metadata;

  /// Null when the sidecar could not be written; the photo is still saved.
  final File? metadataFile;

  bool get hasMetadataFile => metadataFile != null;
}

/// Persists a capture: the original JPEG first, then its metadata sidecar.
class CaptureSaver {
  CaptureSaver(this._storage, {this._video});

  final PhotoStorageService _storage;
  final VideoService? _video;

  /// Saves a recorded video like a photo: the MP4 first, then its sidecar
  /// with the start location, the per-second [track] and the video's size.
  Future<SavedCapture> saveVideo(
    XFile video, {
    required DateTime startedAt,
    required LocationSnapshot location,
    required List<VideoTrackPoint> track,
    String? note,
    CameraDirection? direction,
  }) async {
    final file = await _storage.saveVideo(video, startedAt: startedAt);
    final info = await (_video ?? _findVideo())?.info(file.path);
    final metadata = PhotoMetadata.create(
      imageFileName: file.uri.pathSegments.last,
      capturedAt: startedAt,
      location: location,
      note: note,
      direction: direction,
      video: VideoDetails(
        durationMs: info?.durationMs ?? (track.isEmpty ? 0 : track.last.atMs),
        width: info?.width ?? 0,
        height: info?.height ?? 0,
        hasAudio: info?.hasAudio ?? false,
        track: track,
        // Cleared once the automatic stamped copy is made (or not wanted).
        stampPending: true,
      ),
    );

    File? metadataFile;
    try {
      metadataFile = await _storage.saveMetadata(file, metadata.toJson());
    } on FileSystemException {
      metadataFile = null;
    }
    return SavedCapture(
      photo: file,
      metadata: metadata,
      metadataFile: metadataFile,
    );
  }

  /// Notes what is known about the recording in progress, so it can be
  /// recovered if Android closes the app before [saveVideo] runs.
  Future<void> writeJournal(RecordingJournal journal) async {
    try {
      await _storage.writeJsonAtomic(
        await _storage.recordingJournalFile(),
        journal.toJson(),
      );
    } catch (_) {
      // Only recovery depends on it; recording goes on.
    }
  }

  Future<void> clearJournal() async {
    try {
      final file = await _storage.recordingJournalFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// The camera records into files named like this in the cache.
  static final RegExp _cameraFile = RegExp(r'^REC.*\.mp4$');

  /// Saves a recording that stopped without being saved (Android closed
  /// the app, or the camera stopped it when the app was left), using the
  /// journal written while it recorded. Returns null when there is none or
  /// its file cannot be played; the journal is removed either way.
  Future<SavedCapture?> recoverRecording({
    required Future<Directory> Function() temporaryDirectory,
    Duration settled = const Duration(seconds: 3),
  }) async {
    final journalFile = await _storage.recordingJournalFile();
    if (!await journalFile.exists()) return null;
    RecordingJournal journal;
    try {
      journal = RecordingJournal.fromJson(
        jsonDecode(await journalFile.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      await clearJournal();
      return null;
    }

    final candidates = <(File, DateTime)>[];
    try {
      final from = journal.startedAt.subtract(const Duration(seconds: 10));
      final settledBefore = DateTime.now().subtract(settled);
      await for (final entity in (await temporaryDirectory()).list()) {
        if (entity is! File) continue;
        if (!_cameraFile.hasMatch(entity.uri.pathSegments.last)) continue;
        final modified = await entity.lastModified();
        // Still being written, or from before this recording.
        if (modified.isBefore(from) || modified.isAfter(settledBefore)) {
          continue;
        }
        candidates.add((entity, modified));
      }
    } on FileSystemException {
      return null;
    }
    candidates.sort((a, b) => b.$2.compareTo(a.$2));

    SavedCapture? saved;
    final video = _video ?? _findVideo();
    for (final (file, _) in candidates) {
      final info = await video?.info(file.path);
      // Only a finished file has a length; a cut-off one cannot be played.
      if (info == null || info.durationMs <= 0) continue;
      try {
        saved = await saveVideo(
          XFile(file.path),
          startedAt: journal.startedAt,
          location: journal.location,
          note: journal.note,
          direction: journal.direction,
          track: [
            for (final p in journal.track)
              if (p.atMs <= info.durationMs) p,
          ],
        );
      } catch (_) {
        saved = null;
      }
      break;
    }
    await clearJournal();
    return saved;
  }

  static VideoService? _findVideo() =>
      Get.isRegistered<VideoService>() ? Get.find<VideoService>() : null;

  /// Throws [FileSystemException] only if the photo itself cannot be saved.
  /// A failed sidecar write is reported through [SavedCapture.metadataFile].
  Future<SavedCapture> save(
    XFile image, {
    required DateTime capturedAt,
    required LocationSnapshot location,
    String? note,
    CameraDirection? direction,
  }) async {
    final photo = await _storage.savePhoto(image, capturedAt: capturedAt);
    final metadata = PhotoMetadata.create(
      imageFileName: photo.uri.pathSegments.last,
      capturedAt: capturedAt,
      location: location,
      note: note,
      direction: direction,
    );

    File? metadataFile;
    try {
      metadataFile = await _storage.saveMetadata(photo, metadata.toJson());
    } on FileSystemException {
      metadataFile = null;
    }

    return SavedCapture(
      photo: photo,
      metadata: metadata,
      metadataFile: metadataFile,
    );
  }
}

/// A recording in progress, as written to `GPSCamera/recording.json`.
class RecordingJournal {
  const RecordingJournal({
    required this.startedAt,
    required this.location,
    required this.track,
    this.note,
    this.direction,
  });

  factory RecordingJournal.fromJson(Map<String, dynamic> json) =>
      RecordingJournal(
        startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
        location: LocationSnapshot.fromJson(
          json['location'] as Map<String, dynamic>,
        ),
        note: json['note'] as String?,
        direction: switch (json['direction']) {
          final Map<String, dynamic> d => CameraDirection.fromJson(d),
          _ => null,
        },
        track: [
          for (final p in (json['track'] as List?) ?? const [])
            VideoTrackPoint.fromJson(p as Map<String, dynamic>),
        ],
      );

  final DateTime startedAt;
  final LocationSnapshot location;
  final String? note;
  final CameraDirection? direction;
  final List<VideoTrackPoint> track;

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toUtc().toIso8601String(),
    'location': location.toJson(),
    if (note != null) 'note': note,
    if (direction != null) 'direction': direction!.toJson(),
    'track': [for (final p in track) p.toJson()],
  };
}
