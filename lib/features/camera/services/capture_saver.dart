import 'dart:io';

import 'package:camera/camera.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/location/models/camera_direction.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';

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
  CaptureSaver(this._storage);

  final PhotoStorageService _storage;

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
