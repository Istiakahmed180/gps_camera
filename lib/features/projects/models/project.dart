import 'package:gps_camera/core/database/app_database.dart';

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.coverPhotoRef,
  });

  factory Project.fromRow(ProjectRow row) => Project(
    id: row.id,
    name: row.name,
    description: row.description,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    archivedAt: row.archivedAt,
    coverPhotoRef: row.coverPhotoPath,
  );

  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  /// Relative photo path (see `PhotoRefs`), or null for no cover.
  final String? coverPhotoRef;

  bool get isArchived => archivedAt != null;

  ProjectRef get ref => ProjectRef(id, name);
}

/// The minimum needed to show which project a photo belongs to.
class ProjectRef {
  const ProjectRef(this.id, this.name);

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is ProjectRef && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// A project with its photo count, for lists.
class ProjectSummary {
  const ProjectSummary({
    required this.project,
    required this.photoCount,
    this.latestPhotoRef,
  });

  final Project project;

  /// Original photos assigned. Watermarked copies are not counted twice.
  final int photoCount;

  /// Most recently assigned original, used as a cover when none is set.
  final String? latestPhotoRef;

  String? get displayCoverRef => project.coverPhotoRef ?? latestPhotoRef;
}
