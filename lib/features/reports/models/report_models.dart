import 'package:gps_camera/core/settings/display_format.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';

enum ReportType {
  project('Project report'),
  selection('Selected photos report');

  const ReportType(this.label);

  final String label;
}

enum ReportImageRole { original, watermarked }

/// An image to show for a report entry. Only its path is passed around;
/// pixels are loaded one at a time while rendering.
class ReportImage {
  const ReportImage({
    required this.path,
    required this.fileName,
    required this.role,
  });

  final String path;
  final String fileName;
  final ReportImageRole role;
}

/// A watermarked version of the entry's photo, from its render record.
class ReportWatermark {
  const ReportWatermark({required this.fileName, this.config, this.renderedAt});

  final String fileName;

  /// Null when the render record is missing or damaged.
  final WatermarkConfig? config;
  final DateTime? renderedAt;
}

/// One captured photo in a report. An original and its watermarked copies
/// always share one entry, so a capture never appears twice.
class ReportEntry {
  const ReportEntry({
    required this.fileName,
    required this.originalAvailable,
    required this.images,
    this.metadata,
    this.metadataProblem,
    this.watermarks = const [],
    this.projectName,
    this.otherSelectedCopies = const [],
  });

  /// The original's file name (for a copy whose original is gone, the
  /// name it had).
  final String fileName;

  /// False when the original file no longer exists.
  final bool originalAvailable;

  /// Up to two images: the original and/or watermarked copies.
  final List<ReportImage> images;

  /// Capture metadata exactly as stored; null when unavailable.
  final PhotoMetadata? metadata;

  /// Why [metadata] is null, e.g. "Metadata file is damaged".
  final String? metadataProblem;
  final List<ReportWatermark> watermarks;
  final String? projectName;

  /// Selected watermarked copies that did not fit as images.
  final List<String> otherSelectedCopies;
}

/// Everything needed to render a report. Plain data, so it can be sent to a
/// background isolate.
class ReportJob {
  const ReportJob({
    required this.type,
    required this.title,
    required this.generatedAt,
    required this.entries,
    this.projectId,
    this.projectName,
    this.projectDescription,
    this.format = const DisplayFormat(),
  });

  final ReportType type;
  final String title;

  /// Local time on the device when the report was created.
  final DateTime generatedAt;
  final List<ReportEntry> entries;
  final String? projectId;
  final String? projectName;
  final String? projectDescription;

  /// Units and time format chosen in Settings when the report was made.
  final DisplayFormat format;

  int get watermarkedVersionCount =>
      entries.fold(0, (sum, e) => sum + e.watermarks.length);
}

class ReportProgress {
  const ReportProgress(this.done, this.total, {this.saving = false});

  final int done;
  final int total;
  final bool saving;

  double get fraction => total == 0 ? 0 : done / total;
}
