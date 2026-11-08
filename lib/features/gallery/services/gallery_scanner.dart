import 'dart:convert';
import 'dart:io';

import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/watermark/models/watermark_record.dart';
import 'package:image/image.dart' as img;

/// Reads both photo folders. Pure `dart:io`, so it can run in a background
/// isolate. A bad file only affects its own entry.
GalleryIndex scanGallery(String photosDir, String watermarkedDir) {
  final photos = <GalleryPhoto>[];
  var orphans = 0;
  var complete = true;

  final listedOriginals = _images(photosDir);
  if (listedOriginals == null) complete = false;
  final originals = listedOriginals ?? const <File>[];
  final originalMetadata = <String, PhotoMetadata>{};
  for (final image in originals) {
    final (json, issue) = _readJson(
      PhotoStorageService.sidecarPathFor(image.path),
      missing: GalleryIssue.metadataMissing,
      unreadable: GalleryIssue.metadataUnreadable,
    );
    PhotoMetadata? metadata;
    var finalIssue = issue;
    if (json != null) {
      try {
        metadata = PhotoMetadata.fromJson(json);
      } catch (_) {
        finalIssue = GalleryIssue.metadataUnreadable;
      }
    }
    final stat = _stat(image);
    if (stat == null) continue;
    final name = _name(image.path);
    if (metadata != null) originalMetadata[name] = metadata;
    photos.add(
      GalleryPhoto(
        path: image.path,
        kind: GalleryPhotoKind.original,
        sizeBytes: stat.size,
        modifiedAt: stat.modified,
        metadata: metadata,
        issue: finalIssue,
      ),
    );
  }
  orphans += _orphanSidecars(photosDir, originals);

  final listedOutputs = _images(watermarkedDir);
  if (listedOutputs == null) complete = false;
  final outputs = listedOutputs ?? const <File>[];
  for (final image in outputs) {
    final stat = _stat(image);
    // Zero bytes is a name reserved by a render still in progress.
    if (stat == null || stat.size == 0) continue;

    final (json, issue) = _readJson(
      PhotoStorageService.sidecarPathFor(image.path),
      missing: GalleryIssue.recordMissing,
      unreadable: GalleryIssue.recordUnreadable,
    );
    WatermarkRecord? record;
    var finalIssue = issue;
    if (json != null) {
      try {
        record = WatermarkRecord.fromJson(json);
      } catch (_) {
        finalIssue = GalleryIssue.recordUnreadable;
      }
    }
    final name = _name(image.path);
    final source = record?.sourceImageFileName ?? sourceNameFromOutput(name);
    photos.add(
      GalleryPhoto(
        path: image.path,
        kind: GalleryPhotoKind.watermarked,
        sizeBytes: stat.size,
        modifiedAt: stat.modified,
        record: record,
        sourceFileName: source,
        metadata: record?.sourceMetadata ?? originalMetadata[source],
        issue: finalIssue,
      ),
    );
  }
  orphans += _orphanSidecars(watermarkedDir, outputs);

  return GalleryIndex(
    photos: photos,
    orphanSidecars: orphans,
    complete: complete,
  );
}

/// `IMG_x_wm.jpg` / `IMG_x_wm_3.jpg` → `IMG_x.jpg` (and `VID_x_wm.mp4` →
/// `VID_x.mp4`), for records that are missing or unreadable.
String? sourceNameFromOutput(String outputName) {
  final match = RegExp(
    r'^(.+)_wm(?:_\d+)?\.(jpe?g|mp4)$',
    caseSensitive: false,
  ).firstMatch(outputName);
  if (match == null) return null;
  final video = match.group(2)!.toLowerCase() == 'mp4';
  return '${match.group(1)}.${video ? 'mp4' : 'jpg'}';
}

class ImageDimensions {
  const ImageDimensions(this.width, this.height);

  final int width;
  final int height;
}

/// Reads size from the JPEG header and EXIF orientation without decoding
/// pixels. Returns the size as displayed (rotation applied).
ImageDimensions? readJpegDimensions(String path) {
  try {
    final bytes = File(path).readAsBytesSync();
    final info = img.JpegData().readInfo(bytes);
    if (info == null || info.width == 0 || info.height == 0) return null;
    final orientation = img.decodeJpgExif(bytes)?.imageIfd.orientation ?? 1;
    final rotated = orientation >= 5 && orientation <= 8;
    return rotated
        ? ImageDimensions(info.height, info.width)
        : ImageDimensions(info.width, info.height);
  } catch (_) {
    return null;
  }
}

/// Photos and videos in [dir]. Null when the folder exists but cannot be
/// listed.
List<File>? _images(String dir) {
  final directory = Directory(dir);
  if (!directory.existsSync()) return const [];
  try {
    return directory
        .listSync(followLinks: false)
        .whereType<File>()
        .where(
          (f) =>
              RegExp(r'\.(jpe?g|mp4)$', caseSensitive: false).hasMatch(f.path),
        )
        .toList();
  } on FileSystemException {
    return null;
  }
}

int _orphanSidecars(String dir, List<File> images) {
  final imageBases = {
    for (final image in images) PhotoStorageService.sidecarPathFor(image.path),
  };
  try {
    return Directory(dir)
        .listSync(followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json') && !imageBases.contains(f.path))
        .length;
  } on FileSystemException {
    return 0;
  }
}

FileStat? _stat(File file) {
  final stat = file.statSync();
  return stat.type == FileSystemEntityType.notFound ? null : stat;
}

(Map<String, dynamic>?, GalleryIssue?) _readJson(
  String path, {
  required GalleryIssue missing,
  required GalleryIssue unreadable,
}) {
  final file = File(path);
  if (!file.existsSync()) return (null, missing);
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    return decoded is Map<String, dynamic>
        ? (decoded, null)
        : (null, unreadable);
  } catch (_) {
    return (null, unreadable);
  }
}

String _name(String path) => path.substring(path.lastIndexOf('/') + 1);
