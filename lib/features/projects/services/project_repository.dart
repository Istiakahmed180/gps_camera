import 'dart:math';

import 'package:drift/drift.dart';
import 'package:gps_camera/core/database/app_database.dart';
import 'package:gps_camera/features/projects/models/project.dart';

class ProjectValidationException implements Exception {
  const ProjectValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReconcileResult {
  const ReconcileResult({
    required this.removedAssignments,
    required this.clearedCovers,
  });

  final int removedAssignments;
  final int clearedCovers;

  bool get changedAnything => removedAssignments > 0 || clearedCovers > 0;
}

/// All project and project-photo persistence. Never touches photo files.
class ProjectRepository {
  ProjectRepository(
    this._db, {
    String Function()? newId,
    DateTime Function()? clock,
  }) : _newId = newId ?? _randomId,
       _clock = clock ?? DateTime.now;

  static const int maxNameLength = 80;
  static const int maxDescriptionLength = 1000;

  final AppDatabase _db;
  final String Function() _newId;
  final DateTime Function() _clock;

  // ---- Projects -----------------------------------------------------------

  /// Active or archived projects with photo counts, newest activity first,
  /// optionally filtered by a case-insensitive name/description [query].
  Future<List<ProjectSummary>> summaries({
    required bool archived,
    String query = '',
  }) async {
    final projects = _db.projects;
    final select = _db.select(projects)
      ..where(
        (p) => archived ? p.archivedAt.isNotNull() : p.archivedAt.isNull(),
      )
      ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]);

    final term = query.trim().toLowerCase();
    if (term.isNotEmpty) {
      final pattern = '%${_escapeLike(term)}%';
      select.where(
        (p) =>
            p.name.lower().like(pattern, escapeChar: r'\') |
            p.description.lower().like(pattern, escapeChar: r'\'),
      );
    }
    final rows = await select.get();
    final counts = await _photoCounts();
    final latest = await _latestPhotoRefs();

    return [
      for (final row in rows)
        ProjectSummary(
          project: Project.fromRow(row),
          photoCount: counts[row.id] ?? 0,
          latestPhotoRef: latest[row.id],
        ),
    ];
  }

  /// Projects photos can be assigned to (not archived), by name.
  Future<List<Project>> activeProjects() async {
    final rows =
        await (_db.select(_db.projects)
              ..where((p) => p.archivedAt.isNull())
              ..orderBy([(p) => OrderingTerm.asc(p.name.lower())]))
            .get();
    return rows.map(Project.fromRow).toList();
  }

  Future<Project?> find(String id) async {
    final row = await (_db.select(
      _db.projects,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    return row == null ? null : Project.fromRow(row);
  }

  Future<Project> create({
    required String name,
    String description = '',
  }) async {
    final cleanName = await _validName(name);
    final cleanDescription = _validDescription(description);
    final now = _clock().toUtc();
    final row = ProjectsCompanion.insert(
      id: _newId(),
      name: cleanName,
      description: Value(cleanDescription),
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.projects).insert(row);
    return (await find(row.id.value))!;
  }

  /// Updates name, description and cover. Pass [coverPhotoRef] as null to
  /// clear the cover.
  Future<Project> update(
    String id, {
    required String name,
    required String description,
    required String? coverPhotoRef,
  }) async {
    final cleanName = await _validName(name, excludingId: id);
    final updated =
        await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
          ProjectsCompanion(
            name: Value(cleanName),
            description: Value(_validDescription(description)),
            coverPhotoPath: Value(coverPhotoRef),
            updatedAt: Value(_clock().toUtc()),
          ),
        );
    if (updated == 0) {
      throw const ProjectValidationException('This project no longer exists.');
    }
    return (await find(id))!;
  }

  Future<void> archive(String id) => _setArchived(id, _clock().toUtc());

  Future<void> restore(String id) => _setArchived(id, null);

  /// Deletes the project and its photo assignments. Photo files are not
  /// touched; the photos simply have no project afterwards.
  Future<void> delete(String id) => _db.transaction(() async {
    await (_db.delete(
      _db.projectPhotos,
    )..where((a) => a.projectId.equals(id))).go();
    await (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();
  });

  // ---- Assignments ----------------------------------------------------------

  /// Puts an original photo in [projectId], moving it if it was in another
  /// project. One row per original, so duplicates cannot occur.
  Future<void> assign(String originalRef, String projectId) async {
    final project = await find(projectId);
    if (project == null) {
      throw const ProjectValidationException('This project no longer exists.');
    }
    if (project.isArchived) {
      throw const ProjectValidationException(
        'Archived projects cannot receive photos. Restore it first.',
      );
    }
    await _db
        .into(_db.projectPhotos)
        .insert(
          ProjectPhotosCompanion.insert(
            projectId: projectId,
            originalPhotoPath: originalRef,
            assignedAt: _clock().toUtc(),
          ),
          onConflict: DoUpdate(
            (_) => ProjectPhotosCompanion(
              projectId: Value(projectId),
              assignedAt: Value(_clock().toUtc()),
            ),
            target: [_db.projectPhotos.originalPhotoPath],
          ),
        );
  }

  Future<void> assignAll(Iterable<String> originalRefs, String projectId) =>
      _db.transaction(() async {
        for (final ref in originalRefs) {
          await assign(ref, projectId);
        }
      });

  Future<void> unassign(String originalRef) => (_db.delete(
    _db.projectPhotos,
  )..where((a) => a.originalPhotoPath.equals(originalRef))).go();

  /// Every assignment, keyed by original photo ref, with project names.
  Future<Map<String, ProjectRef>> assignments() async {
    final query = _db.select(_db.projectPhotos).join([
      innerJoin(
        _db.projects,
        _db.projects.id.equalsExp(_db.projectPhotos.projectId),
      ),
    ]);
    final rows = await query.get();
    return {
      for (final row in rows)
        row.readTable(_db.projectPhotos).originalPhotoPath: ProjectRef(
          row.readTable(_db.projects).id,
          row.readTable(_db.projects).name,
        ),
    };
  }

  Future<Set<String>> photoRefsOf(String projectId) async {
    final rows = await (_db.select(
      _db.projectPhotos,
    )..where((a) => a.projectId.equals(projectId))).get();
    return {for (final row in rows) row.originalPhotoPath};
  }

  // ---- Consistency ----------------------------------------------------------

  /// Call after photo files are deleted: drops their assignments and clears
  /// any project cover that pointed at them. Projects are never deleted.
  Future<void> forgetPhotos(Iterable<String> refs) async {
    final list = refs.toList();
    if (list.isEmpty) return;
    await _db.transaction(() async {
      await (_db.delete(
        _db.projectPhotos,
      )..where((a) => a.originalPhotoPath.isIn(list))).go();
      await (_db.update(_db.projects)
            ..where((p) => p.coverPhotoPath.isIn(list)))
          .write(const ProjectsCompanion(coverPhotoPath: Value(null)));
    });
  }

  /// Repairs rows that point at files which no longer exist (deleted
  /// outside the app, or a crash between deleting a file and updating the
  /// database). [existingRefs] must come from a complete scan started at
  /// [scannedAt]; rows written after that are left alone.
  Future<ReconcileResult> reconcile({
    required Set<String> existingRefs,
    required DateTime scannedAt,
  }) => _db.transaction(() async {
    final assignments = await (_db.select(
      _db.projectPhotos,
    )..where((a) => a.assignedAt.isSmallerThanValue(scannedAt.toUtc()))).get();
    final stale = [
      for (final row in assignments)
        if (!existingRefs.contains(row.originalPhotoPath)) row.id,
    ];
    if (stale.isNotEmpty) {
      await (_db.delete(
        _db.projectPhotos,
      )..where((a) => a.id.isIn(stale))).go();
    }

    final covered = await (_db.select(
      _db.projects,
    )..where((p) => p.coverPhotoPath.isNotNull())).get();
    final staleCovers = [
      for (final row in covered)
        if (!existingRefs.contains(row.coverPhotoPath)) row.id,
    ];
    if (staleCovers.isNotEmpty) {
      await (_db.update(_db.projects)..where((p) => p.id.isIn(staleCovers)))
          .write(const ProjectsCompanion(coverPhotoPath: Value(null)));
    }
    return ReconcileResult(
      removedAssignments: stale.length,
      clearedCovers: staleCovers.length,
    );
  });

  // ---- Internals ------------------------------------------------------------

  Future<void> _setArchived(String id, DateTime? at) async {
    await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(
        archivedAt: Value(at),
        updatedAt: Value(_clock().toUtc()),
      ),
    );
  }

  Future<String> _validName(String name, {String? excludingId}) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) {
      throw const ProjectValidationException('Enter a project name.');
    }
    if (clean.length > maxNameLength) {
      throw const ProjectValidationException(
        'Use $maxNameLength characters or fewer.',
      );
    }
    final clash =
        await (_db.select(_db.projects)..where(
              (p) =>
                  p.name.lower().equals(clean.toLowerCase()) &
                  (excludingId == null
                      ? const Constant(true)
                      : p.id.equals(excludingId).not()),
            ))
            .getSingleOrNull();
    if (clash != null) {
      throw ProjectValidationException(
        'A project named "${clash.name}" already exists.',
      );
    }
    return clean;
  }

  String _validDescription(String description) {
    final clean = description.trim();
    if (clean.length > maxDescriptionLength) {
      throw const ProjectValidationException(
        'Keep the description under $maxDescriptionLength characters.',
      );
    }
    return clean;
  }

  Future<Map<String, int>> _photoCounts() async {
    final count = _db.projectPhotos.id.count();
    final rows =
        await (_db.selectOnly(_db.projectPhotos)
              ..addColumns([_db.projectPhotos.projectId, count])
              ..groupBy([_db.projectPhotos.projectId]))
            .get();
    return {
      for (final row in rows)
        row.read(_db.projectPhotos.projectId)!: row.read(count) ?? 0,
    };
  }

  Future<Map<String, String>> _latestPhotoRefs() async {
    final rows = await (_db.select(
      _db.projectPhotos,
    )..orderBy([(a) => OrderingTerm.desc(a.assignedAt)])).get();
    final latest = <String, String>{};
    for (final row in rows) {
      latest.putIfAbsent(row.projectId, () => row.originalPhotoPath);
    }
    return latest;
  }

  static String _escapeLike(String value) =>
      value.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');

  static String _randomId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
