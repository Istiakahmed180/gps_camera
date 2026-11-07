import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';

import 'helpers/db_fixtures.dart';

void main() {
  late DbFixture fx;
  late ProjectRepository repo;

  setUp(() {
    fx = DbFixture();
    repo = fx.repo;
  });
  tearDown(() => fx.close());

  Matcher invalid(String text) => throwsA(
    isA<ProjectValidationException>().having(
      (e) => e.message,
      'message',
      contains(text),
    ),
  );

  group('projects', () {
    test('creates with a trimmed name and unique id', () async {
      final a = await repo.create(name: '  Site   A ', description: ' Roof ');
      final b = await repo.create(name: 'Site B');

      expect(a.name, 'Site A');
      expect(a.description, 'Roof');
      expect(a.id, isNot(b.id));
      expect(a.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(a.createdAt, fx.now);
      expect(a.isArchived, isFalse);
    });

    test('rejects empty, too long and duplicate names', () async {
      await expectLater(repo.create(name: '   '), invalid('Enter a project'));
      await expectLater(repo.create(name: 'x' * 81), invalid('80 characters'));
      await repo.create(name: 'Bridge');
      await expectLater(repo.create(name: 'bridge'), invalid('already exists'));
    });

    test('edits name, description and cover', () async {
      final p = await repo.create(name: 'Old');
      fx.advance();
      final updated = await repo.update(
        p.id,
        name: 'New',
        description: 'Details',
        coverPhotoRef: 'Photos/IMG_1.jpg',
      );

      expect(updated.name, 'New');
      expect(updated.description, 'Details');
      expect(updated.coverPhotoRef, 'Photos/IMG_1.jpg');
      expect(updated.updatedAt, fx.now);
      expect(updated.createdAt, p.createdAt);
      await expectLater(
        repo.update(p.id, name: '', description: '', coverPhotoRef: null),
        invalid('Enter a project'),
      );
      expect(
        (await repo.update(
          p.id,
          name: 'New',
          description: '',
          coverPhotoRef: null,
        )).name,
        'New',
        reason: 'keeping its own name is not a duplicate',
      );
    });

    test(
      'archives and restores; archived projects leave the active list',
      () async {
        final p = await repo.create(name: 'A');
        await repo.archive(p.id);

        expect((await repo.find(p.id))!.isArchived, isTrue);
        expect(await repo.summaries(archived: false), isEmpty);
        expect((await repo.summaries(archived: true)).single.project.id, p.id);
        expect(await repo.activeProjects(), isEmpty);

        await repo.restore(p.id);
        expect((await repo.find(p.id))!.isArchived, isFalse);
        expect((await repo.summaries(archived: false)), hasLength(1));
      },
    );

    test('search matches name or description, case-insensitively', () async {
      await repo.create(name: 'North Bridge', description: 'steel');
      await repo.create(name: 'Tower', description: 'Concrete pour');
      await repo.create(name: '100% done');

      Future<List<String>> names(String q) async => (await repo.summaries(
        archived: false,
        query: q,
      )).map((s) => s.project.name).toList();

      expect(await names('bridge'), ['North Bridge']);
      expect(await names('CONCRETE'), ['Tower']);
      expect(await names('%'), ['100% done']);
      expect(await names('zzz'), isEmpty);
    });
  });

  group('assignments', () {
    test('assigns a photo and counts it', () async {
      final p = await repo.create(name: 'A');
      await repo.assign('Photos/IMG_1.jpg', p.id);

      final summary = (await repo.summaries(archived: false)).single;
      expect(summary.photoCount, 1);
      expect(summary.latestPhotoRef, 'Photos/IMG_1.jpg');
      expect((await repo.assignments())['Photos/IMG_1.jpg']!.name, 'A');
    });

    test(
      'assigning twice never duplicates; assigning elsewhere moves it',
      () async {
        final a = await repo.create(name: 'A');
        final b = await repo.create(name: 'B');
        await repo.assign('Photos/IMG_1.jpg', a.id);
        await repo.assign('Photos/IMG_1.jpg', a.id);
        expect(await repo.photoRefsOf(a.id), {'Photos/IMG_1.jpg'});
        expect(await fx.db.select(fx.db.projectPhotos).get(), hasLength(1));

        await repo.assign('Photos/IMG_1.jpg', b.id);
        expect(await repo.photoRefsOf(a.id), isEmpty);
        expect(await repo.photoRefsOf(b.id), {'Photos/IMG_1.jpg'});
        expect(await fx.db.select(fx.db.projectPhotos).get(), hasLength(1));
      },
    );

    test('removes an assignment', () async {
      final a = await repo.create(name: 'A');
      await repo.assign('Photos/IMG_1.jpg', a.id);
      await repo.unassign('Photos/IMG_1.jpg');
      expect(await repo.assignments(), isEmpty);
    });

    test('archived or missing projects cannot receive photos', () async {
      final a = await repo.create(name: 'A');
      await repo.archive(a.id);
      await expectLater(
        repo.assign('Photos/IMG_1.jpg', a.id),
        invalid('Archived'),
      );
      await expectLater(
        repo.assign('Photos/IMG_1.jpg', 'nope'),
        invalid('no longer exists'),
      );
    });

    test('deleting a project removes only its rows', () async {
      final a = await repo.create(name: 'A');
      final b = await repo.create(name: 'B');
      await repo.assignAll(['Photos/1.jpg', 'Photos/2.jpg'], a.id);
      await repo.assign('Photos/3.jpg', b.id);

      await repo.delete(a.id);

      expect(await repo.find(a.id), isNull);
      expect((await repo.assignments()).keys, ['Photos/3.jpg']);
    });

    test(
      'forgetting deleted photos keeps the project and clears its cover',
      () async {
        final a = await repo.create(name: 'A');
        await repo.assignAll(['Photos/1.jpg', 'Photos/2.jpg'], a.id);
        await repo.update(
          a.id,
          name: 'A',
          description: '',
          coverPhotoRef: 'Photos/1.jpg',
        );

        await repo.forgetPhotos(['Photos/1.jpg']);

        final project = (await repo.find(a.id))!;
        expect(project.coverPhotoRef, isNull);
        expect(await repo.photoRefsOf(a.id), {'Photos/2.jpg'});
      },
    );
  });

  group('reconcile', () {
    test('removes rows for missing files written before the scan', () async {
      final a = await repo.create(name: 'A');
      await repo.assignAll(['Photos/kept.jpg', 'Photos/gone.jpg'], a.id);
      await repo.update(
        a.id,
        name: 'A',
        description: '',
        coverPhotoRef: 'Watermarked/gone_wm.jpg',
      );
      fx.advance();
      final scannedAt = fx.now;
      fx.advance();
      await repo.assign('Photos/new_during_scan.jpg', a.id);

      final result = await repo.reconcile(
        existingRefs: {'Photos/kept.jpg'},
        scannedAt: scannedAt,
      );

      expect(result.removedAssignments, 1);
      expect(result.clearedCovers, 1);
      expect(await repo.photoRefsOf(a.id), {
        'Photos/kept.jpg',
        'Photos/new_during_scan.jpg',
      });
      expect(await repo.find(a.id), isNotNull);
    });

    test('a consistent database is left unchanged', () async {
      final a = await repo.create(name: 'A');
      await repo.assign('Photos/1.jpg', a.id);
      fx.advance();
      final result = await repo.reconcile(
        existingRefs: {'Photos/1.jpg'},
        scannedAt: fx.now,
      );
      expect(result.changedAnything, isFalse);
    });
  });
}
