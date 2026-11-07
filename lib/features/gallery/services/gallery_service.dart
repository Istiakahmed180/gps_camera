import 'dart:io';
import 'dart:isolate';

import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_scanner.dart';

typedef FileDeleter = Future<void> Function(File file);

/// What deleting [target] would affect, shown to the user before deleting.
class DeletePlan {
  const DeletePlan({required this.target, this.related = const []});

  final GalleryPhoto target;

  /// Watermarked copies of an original. Deleted only if the user agrees.
  final List<GalleryPhoto> related;

  bool get hasRelated => related.isNotEmpty;
}

class DeleteFailure {
  const DeleteFailure(this.fileName, this.message);

  final String fileName;
  final String message;
}

class DeleteResult {
  const DeleteResult({
    required this.deleted,
    required this.failures,
    this.removedPhotos = const [],
  });

  /// File names removed, images and JSON.
  final List<String> deleted;

  /// Photos whose image file no longer exists after this delete.
  final List<GalleryPhoto> removedPhotos;
  final List<DeleteFailure> failures;

  bool get isComplete => failures.isEmpty;
}

/// Scanning and deleting photos. File locations come from
/// [PhotoStorageService]; nothing here writes images.
class GalleryService {
  GalleryService(this._storage, {FileDeleter? deleteFile})
    : _deleteFile = deleteFile ?? _delete;

  final PhotoStorageService _storage;
  final FileDeleter _deleteFile;

  /// Sets or clears an original's note, re-reading the sidecar first so no
  /// other change is lost. Only the note changes. Throws on failure.
  Future<String?> updateNote(GalleryPhoto photo, String? note) async {
    if (!photo.isOriginal) {
      throw StateError('Notes belong to originals');
    }
    final json = await _storage.readMetadata(photo.file);
    if (json == null) throw StateError('This photo has no metadata');
    final next = PhotoMetadata.fromJson(json).withNote(note);
    await _storage.saveMetadata(photo.file, next.toJson());
    return next.note;
  }

  /// Scans both folders in a background isolate.
  Future<GalleryIndex> scan() async {
    final photos = (await _storage.photosDirectory()).path;
    final outputs = (await _storage.watermarkedDirectory()).path;
    return Isolate.run(() => scanGallery(photos, outputs));
  }

  /// Displayed size. Watermarked copies use their render record; originals
  /// read the JPEG header only.
  Future<ImageDimensions?> dimensionsOf(GalleryPhoto photo) async {
    final record = photo.record;
    if (record != null) {
      return ImageDimensions(record.imageWidth, record.imageHeight);
    }
    final path = photo.path;
    return Isolate.run(() => readJpegDimensions(path));
  }

  /// Plans for deleting several photos. A selected original takes its
  /// copies along when [includeRelated]; a copy whose original is also
  /// being deleted with its copies is not planned twice.
  List<DeletePlan> planDeleteMany(
    List<GalleryPhoto> photos,
    GalleryIndex index, {
    required bool includeRelated,
  }) {
    final ids = {for (final p in photos) p.id};
    return [
      for (final photo in photos)
        if (!(includeRelated &&
            photo.isWatermarked &&
            index.sourceOf(photo) != null &&
            ids.contains(index.sourceOf(photo)!.id)))
          planDelete(photo, index),
    ];
  }

  DeletePlan planDelete(GalleryPhoto photo, GalleryIndex index) =>
      DeletePlan(target: photo, related: index.variantsOf(photo));

  /// Deletes the target (and its related copies when [includeRelated]),
  /// each image before its JSON. A JSON file is only removed once its image
  /// is gone, so a failure never leaves an image without its metadata.
  /// Every failure is reported; nothing is claimed that did not happen.
  Future<DeleteResult> delete(
    DeletePlan plan, {
    required bool includeRelated,
  }) async {
    final deleted = <String>[];
    final failures = <DeleteFailure>[];
    final removed = <GalleryPhoto>[];
    final photos = [if (includeRelated) ...plan.related, plan.target];

    for (final photo in photos) {
      final imageGone = await _remove(photo.file, deleted, failures);
      if (imageGone) {
        removed.add(photo);
        await _remove(
          File(PhotoStorageService.sidecarPathFor(photo.path)),
          deleted,
          failures,
        );
        if (photo.isOriginal) {
          await _remove(
            await _storage.mapImageFor(photo.file),
            deleted,
            failures,
          );
        }
      }
    }
    return DeleteResult(
      deleted: deleted,
      failures: failures,
      removedPhotos: removed,
    );
  }

  /// True when the file no longer exists afterwards.
  Future<bool> _remove(
    File file,
    List<String> deleted,
    List<DeleteFailure> failures,
  ) async {
    final name = file.uri.pathSegments.last;
    if (!await file.exists()) return true;
    try {
      await _deleteFile(file);
      deleted.add(name);
      return true;
    } on FileSystemException catch (e) {
      failures.add(DeleteFailure(name, e.osError?.message ?? e.message));
      return false;
    }
  }

  static Future<void> _delete(File file) => file.delete();
}
