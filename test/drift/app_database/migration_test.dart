import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/database/app_database.dart';

import 'generated/schema.dart';

/// Guards the database schema across app versions.
///
/// Every schema change must bump [AppDatabase.schemaVersion], export the
/// schema with `dart run drift_dev make-migrations`, and add a
/// `migrateAndValidate` case below for the upgrade from each older version.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('the current schema matches exported v1 exactly', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });

  test('a fresh database is created at the current version', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final version = await db
        .customSelect('PRAGMA user_version')
        .map((row) => row.read<int>('user_version'))
        .getSingle();
    expect(version, db.schemaVersion);

    final foreignKeys = await db
        .customSelect('PRAGMA foreign_keys')
        .map((row) => row.read<int>('foreign_keys'))
        .getSingle();
    expect(foreignKeys, 1, reason: 'cascade deletes depend on this');
    await db.close();
  });

  test('a database from a newer app version is refused, not altered', () async {
    final dir = await Directory.systemTemp.createTemp('db');
    final file = File('${dir.path}/app.sqlite');

    final first = AppDatabase(NativeDatabase(file));
    await first.customStatement('SELECT 1');
    await first.close();

    final raw = NativeDatabase(file);
    await raw.ensureOpen(_NoUser());
    await raw.runCustom('PRAGMA user_version = 2');
    await raw.close();

    final reopened = AppDatabase(NativeDatabase(file));
    await expectLater(
      reopened.customSelect('SELECT 1').get(),
      throwsA(isA<StateError>()),
    );
    await reopened.close();
  });
}

class _NoUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
