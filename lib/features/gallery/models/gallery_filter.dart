import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/projects/models/project.dart';

enum GalleryFilter {
  all('All'),
  originals('Originals'),
  watermarked('Watermarked'),
  videos('Videos');

  const GalleryFilter(this.label);

  final String label;

  bool matches(GalleryPhoto photo) => switch (this) {
    GalleryFilter.all => true,
    GalleryFilter.originals => photo.isOriginal,
    GalleryFilter.watermarked => photo.isWatermarked,
    GalleryFilter.videos => photo.isVideo,
  };
}

enum GallerySort {
  newestFirst('Newest first'),
  oldestFirst('Oldest first');

  const GallerySort(this.label);

  final String label;
}

/// Narrows the gallery to one project, to photos without a project, or not
/// at all. Watermarked copies match through their original.
class ProjectFilter {
  const ProjectFilter._(this.projectId, {this.unassigned = false});

  const ProjectFilter.project(String id) : this._(id);

  static const ProjectFilter any = ProjectFilter._(null);
  static const ProjectFilter none = ProjectFilter._(null, unassigned: true);

  final String? projectId;
  final bool unassigned;

  bool get isActive => projectId != null || unassigned;

  bool matches(ProjectRef? project) {
    if (unassigned) return project == null;
    if (projectId == null) return true;
    return project?.id == projectId;
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectFilter &&
      other.projectId == projectId &&
      other.unassigned == unassigned;

  @override
  int get hashCode => Object.hash(projectId, unassigned);
}
