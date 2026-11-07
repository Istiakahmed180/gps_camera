import 'dart:io';

import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/watermark/models/watermark_record.dart';

enum GalleryPhotoKind { original, watermarked }

/// Something about a photo's companion JSON that the user should know.
enum GalleryIssue {
  /// An original without a metadata sidecar.
  metadataMissing,

  /// An original whose sidecar exists but cannot be read.
  metadataUnreadable,

  /// A watermarked copy without its render record.
  recordMissing,

  /// A watermarked copy whose render record cannot be read.
  recordUnreadable,
}

/// One image file found in app storage, with whatever metadata could be
/// read for it.
class GalleryPhoto {
  const GalleryPhoto({
    required this.path,
    required this.kind,
    required this.sizeBytes,
    required this.modifiedAt,
    this.metadata,
    this.record,
    this.sourceFileName,
    this.issue,
  });

  final String path;
  final GalleryPhotoKind kind;
  final int sizeBytes;
  final DateTime modifiedAt;

  /// Capture metadata. For a watermarked copy this comes from its render
  /// record, or from its original's sidecar for older records.
  final PhotoMetadata? metadata;

  /// Render record, for watermarked copies only.
  final WatermarkRecord? record;

  /// File name of the original a watermarked copy was made from.
  final String? sourceFileName;
  final GalleryIssue? issue;

  String get fileName => path.substring(path.lastIndexOf('/') + 1);

  File get file => File(path);

  /// Unique across both folders.
  String get id => '${kind.name}/$fileName';

  bool get isOriginal => kind == GalleryPhotoKind.original;

  bool get isWatermarked => kind == GalleryPhotoKind.watermarked;

  DateTime? get capturedAt => metadata?.capturedAt;

  /// When this file was made: capture time for originals, render time for
  /// watermarked copies. Used for sorting so new outputs appear first.
  DateTime get savedAt => switch (kind) {
    GalleryPhotoKind.original => metadata?.capturedAt ?? modifiedAt,
    GalleryPhotoKind.watermarked => record?.renderedAt ?? modifiedAt,
  };
}
