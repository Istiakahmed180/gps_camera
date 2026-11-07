import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// A user-created project. Photo files are never stored here, only paths.
@DataClassName('ProjectRow')
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  /// Path relative to the `GPSCamera/` folder, e.g. `Photos/IMG_x.jpg`.
  TextColumn get coverPhotoPath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Which project an original photo belongs to. Watermarked copies have no
/// rows; they inherit through their original. The unique path makes each
/// original belong to at most one project and prevents duplicate rows.
@DataClassName('ProjectPhotoRow')
@TableIndex(name: 'project_photos_project_id', columns: {#projectId})
class ProjectPhotos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// Path relative to the `GPSCamera/` folder, e.g. `Photos/IMG_x.jpg`.
  TextColumn get originalPhotoPath => text().unique()();
  DateTimeColumn get assignedAt => dateTime()();
}

@DriftDatabase(tables: [Projects, ProjectPhotos])
class AppDatabase extends _$AppDatabase {
  /// Opens `gps_camera.sqlite` in app documents on a background isolate.
  /// The connection is created lazily on first query, so constructing this
  /// never blocks the UI. Tests pass an in-memory [executor].
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'gps_camera'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Each schema change bumps [schemaVersion] and adds one step here,
      // generated with `dart run drift_dev make-migrations` and covered by
      // the tests it creates under test/drift/.
      if (from > to) {
        throw StateError('Cannot downgrade database from v$from to v$to');
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
