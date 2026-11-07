import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';

/// Turns gallery photos into report entries: one entry per capture, using
/// only stored metadata and render records.
abstract final class ReportEntryBuilder {
  static const int maxImagesPerEntry = 2;

  /// Every original in a project's [index], oldest capture first, each with
  /// its newest watermarked version shown alongside when one exists.
  static List<ReportEntry> forProject(GalleryIndex index) {
    final entries = [
      for (final original in index.photos.where((p) => p.isOriginal))
        _entry(
          original: original,
          variants: index.variantsOf(original),
          shown: [original, ...index.variantsOf(original).take(1)],
        ),
    ];
    return _chronological(entries);
  }

  /// The user's selection, combined per capture: selecting an original and
  /// its copy gives one entry. Shown images are what the user selected
  /// (original first). Metadata always comes from the original, or from the
  /// copy's render record if the original was deleted.
  static List<ReportEntry> forSelection(
    List<GalleryPhoto> selected,
    GalleryIndex index, {
    ProjectRef? Function(GalleryPhoto photo)? projectOf,
  }) {
    final groups = <String, List<GalleryPhoto>>{};
    for (final photo in selected) {
      final key = photo.isOriginal
          ? photo.fileName
          : photo.sourceFileName ?? 'copy:${photo.fileName}';
      final group = groups.putIfAbsent(key, () => []);
      if (!group.any((p) => p.id == photo.id)) group.add(photo);
    }

    final entries = <ReportEntry>[];
    for (final group in groups.values) {
      final selectedOriginal = group.where((p) => p.isOriginal).firstOrNull;
      final copies = group.where((p) => p.isWatermarked).toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      final original =
          selectedOriginal ??
          (copies.isEmpty ? null : index.sourceOf(copies.first));
      final shown = [?selectedOriginal, ...copies];

      entries.add(
        _entry(
          original: original,
          fallback: copies.firstOrNull,
          variants: original == null ? copies : index.variantsOf(original),
          shown: shown,
          projectName: projectOf?.call(group.first)?.name,
        ),
      );
    }
    return _chronological(entries);
  }

  static ReportEntry _entry({
    required GalleryPhoto? original,
    required List<GalleryPhoto> variants,
    required List<GalleryPhoto> shown,
    GalleryPhoto? fallback,
    String? projectName,
  }) {
    final source = original ?? fallback!;
    final images = [
      for (final photo in shown.take(maxImagesPerEntry))
        ReportImage(
          path: photo.path,
          fileName: photo.fileName,
          role: photo.isOriginal
              ? ReportImageRole.original
              : ReportImageRole.watermarked,
        ),
    ];
    return ReportEntry(
      fileName: original?.fileName ?? source.sourceFileName ?? source.fileName,
      originalAvailable: original != null,
      images: images,
      metadata: source.metadata,
      metadataProblem: source.metadata == null ? _problem(source) : null,
      watermarks: [
        for (final copy in variants)
          ReportWatermark(
            fileName: copy.fileName,
            config: copy.record?.config,
            renderedAt: copy.record?.renderedAt,
          ),
      ],
      projectName: projectName,
      otherSelectedCopies: [
        for (final photo in shown.skip(maxImagesPerEntry)) photo.fileName,
      ],
    );
  }

  static String _problem(GalleryPhoto photo) => switch (photo.issue) {
    GalleryIssue.metadataMissing => 'No metadata was saved for this photo',
    GalleryIssue.metadataUnreadable => 'Metadata file is damaged',
    GalleryIssue.recordMissing => 'Render record is missing',
    GalleryIssue.recordUnreadable => 'Render record is damaged',
    null => 'Metadata unavailable',
  };

  /// Oldest capture first; entries without a capture time go last.
  static List<ReportEntry> _chronological(List<ReportEntry> entries) {
    return entries..sort((a, b) {
      final at = a.metadata?.capturedAt;
      final bt = b.metadata?.capturedAt;
      if (at == null && bt == null) return a.fileName.compareTo(b.fileName);
      if (at == null) return 1;
      if (bt == null) return -1;
      final byTime = at.compareTo(bt);
      return byTime != 0 ? byTime : a.fileName.compareTo(b.fileName);
    });
  }
}
