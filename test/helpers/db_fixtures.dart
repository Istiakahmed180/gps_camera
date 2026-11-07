import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:gps_camera/core/database/app_database.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

/// A fresh in-memory database and a repository with a controllable clock.
class DbFixture {
  DbFixture() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    repo = ProjectRepository(db, clock: () => now);
  }

  late final AppDatabase db;
  late final ProjectRepository repo;
  DateTime now = DateTime.utc(2026, 1, 2, 10);

  void advance([Duration by = const Duration(minutes: 1)]) => now = now.add(by);

  Future<void> close() => db.close();
}
