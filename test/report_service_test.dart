import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/reports/models/report_record.dart';
import 'package:gps_camera/features/reports/services/pdf_report_renderer.dart';
import 'package:gps_camera/features/reports/services/report_service.dart';
import 'package:share_plus/share_plus.dart';

import 'helpers/gallery_fixtures.dart';
import 'helpers/report_fixtures.dart';
import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GalleryFixture fx;
  late PhotoStorageService storage;
  late Directory reports;
  ShareParams? shared;

  ReportService service({ReportRunner? runner}) => ReportService(
    storage,
    ShareService(
      share: (params) async {
        shared = params;
        return const ShareResult('', ShareResultStatus.dismissed);
      },
    ),
    fonts: () async => testReportFonts(),
    runner: runner,
  );

  ReportEntry entry(String name, {String? path}) => ReportEntry(
    fileName: name,
    originalAvailable: true,
    images: [
      ReportImage(
        path: path ?? '${fx.photos.path}/$name',
        fileName: name,
        role: ReportImageRole.original,
      ),
    ],
    metadata: fixtureMetadata(),
  );

  ReportJob job(int count, {String project = 'North Bridge / Phase 2'}) =>
      ReportJob(
        type: ReportType.project,
        title: 'Project report: $project',
        projectId: 'p1',
        projectName: project,
        generatedAt: DateTime(2026, 11, 7, 11, 30, 5),
        entries: [for (var i = 0; i < count; i++) entry('IMG_$i.jpg')],
      );

  List<String> files(Directory dir) =>
      dir.listSync().map((f) => f.uri.pathSegments.last).toList()..sort();

  setUp(() async {
    fx = GalleryFixture(await mockPathProvider());
    for (var i = 0; i < 3; i++) {
      fx.original('IMG_$i');
    }
    storage = PhotoStorageService();
    reports = await storage.reportsDirectory();
    shared = null;
  });

  group('generate', () {
    test('saves a PDF and its record under a safe unique name', () async {
      final result = await service().generate(job(3));

      expect(
        result.file.path,
        '${reports.path}/Report_North-Bridge-Phase-2_20261107_113005.pdf',
      );
      expect(looksLikePdf(result.file), isTrue);
      expect(result.record.photoCount, 3);
      expect(result.record.pageCount, greaterThanOrEqualTo(2));
      final record = jsonDecode(
        File(result.file.path.replaceAll('.pdf', '.json')).readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(record['projectName'], 'North Bridge / Phase 2');
      expect(record['type'], 'project');
      expect(files(reports).where((f) => f.endsWith('.tmp')), isEmpty);
    });

    test('never overwrites an earlier report', () async {
      final first = await service().generate(job(1));
      final bytes = first.file.readAsBytesSync();
      final second = await service().generate(job(2));

      expect(second.file.path, endsWith('_113005_1.pdf'));
      expect(first.file.readAsBytesSync(), bytes);
      expect(files(reports), hasLength(4));
    });

    test('renders many pages and missing images without failing', () async {
      final result = await service().generate(
        ReportJob(
          type: ReportType.selection,
          title: 'Selected photos report',
          generatedAt: DateTime(2026, 11, 7),
          entries: [
            for (var i = 0; i < 9; i++)
              entry(
                'IMG_x$i.jpg',
                path: '${fx.photos.path}/does_not_exist.jpg',
              ),
          ],
        ),
      );
      expect(result.record.pageCount, greaterThanOrEqualTo(4));
      expect(result.file.path, contains('Report_Selection_'));
    });

    test('handles a large collection', () async {
      final big = writeTestJpeg(
        '${fx.root.path}/big.jpg',
        width: 1080,
        height: 1920,
      );
      final result = await service().generate(
        ReportJob(
          type: ReportType.project,
          title: 'Large',
          projectName: 'Large',
          generatedAt: DateTime(2026, 11, 7),
          entries: [
            for (var i = 0; i < 150; i++) entry('IMG_$i.jpg', path: big.path),
          ],
        ),
      );
      expect(result.record.pageCount, greaterThanOrEqualTo(70));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('refuses empty and oversized reports', () async {
      await expectLater(
        service().generate(job(0)),
        throwsA(isA<ReportException>()),
      );
      await expectLater(
        service().generate(job(ReportService.maxPhotos + 1)),
        throwsA(isA<ReportException>()),
      );
      expect(files(reports), isEmpty);
    });

    test('a failure leaves no partial or reserved files', () async {
      final failing = service(
        runner: (job, fonts, path, onProgress) async {
          File(path).writeAsStringSync('%PDF-partial');
          throw StateError('renderer crashed');
        },
      );
      await expectLater(
        failing.generate(job(2)),
        throwsA(isA<ReportException>()),
      );
      expect(files(reports), isEmpty);
      expect(failing.isGenerating.value, isFalse);
    });

    test('a renderer that writes nothing is reported, not saved', () async {
      final silent = service(
        runner: (job, fonts, path, onProgress) async => const ReportRenderStats(
          pageCount: 1,
          imageCount: 0,
          missingImages: 0,
        ),
      );
      await expectLater(
        silent.generate(job(1)),
        throwsA(isA<ReportException>()),
      );
      expect(files(reports), isEmpty);
    });

    test('only one report is generated at a time', () async {
      final gate = Completer<void>();
      final started = Completer<void>();
      final slow = service(
        runner: (job, fonts, path, onProgress) async {
          onProgress(const ReportProgress(1, 2));
          started.complete();
          await gate.future;
          File(path).writeAsStringSync('%PDF-1.4');
          return const ReportRenderStats(
            pageCount: 1,
            imageCount: 0,
            missingImages: 0,
          );
        },
      );
      final first = slow.generate(job(2));
      await started.future;

      expect(slow.isGenerating.value, isTrue);
      expect(slow.progress.value!.done, 1);
      await expectLater(slow.generate(job(1)), throwsA(isA<ReportException>()));

      gate.complete();
      await first;
      expect(slow.isGenerating.value, isFalse);
    });
  });

  group('history', () {
    test(
      'lists finished reports newest first, skipping partial files',
      () async {
        final s = service();
        final a = await s.generate(job(1));
        final b = await s.generate(
          ReportJob(
            type: ReportType.selection,
            title: 'Selected photos report',
            generatedAt: DateTime(2026, 11, 8),
            entries: [entry('IMG_0.jpg')],
          ),
        );
        File('${reports.path}/Report_reserved.pdf').createSync();
        File('${reports.path}/Report_x.pdf.tmp').writeAsStringSync('x');
        File('${reports.path}/Report_norecord.pdf')
            .writeAsStringSync('%PDF-1.4');

        final history = await s.history();

        final names = history.map((r) => r.fileName).toList();
        expect(names.toSet(), {
          'Report_norecord.pdf',
          b.record.fileName,
          a.record.fileName,
        });
        expect(
          names.indexOf(b.record.fileName),
          lessThan(names.indexOf(a.record.fileName)),
          reason: 'newest first',
        );
        expect(
          history
              .firstWhere((r) => r.fileName == b.record.fileName)
              .record!
              .type,
          ReportType.selection,
        );
        expect(
          history.firstWhere((r) => r.fileName == 'Report_norecord.pdf').record,
          isNull,
        );
      },
    );

    test('deleting a report removes only the PDF and its record', () async {
      final s = service();
      await s.generate(job(2));
      final photosBefore = files(fx.photos);
      final report = (await s.history()).single;

      await s.delete(report);

      expect(files(reports), isEmpty);
      expect(files(fx.photos), photosBefore);
    });

    test('refuses to delete files outside the reports folder', () async {
      final s = service();
      final photo = File('${fx.photos.path}/IMG_0.jpg');
      final history = await s.history();
      expect(history, isEmpty);

      final stat = photo.statSync();
      await expectLater(
        s.delete(
          ReportFile(
            file: photo,
            sizeBytes: stat.size,
            modifiedAt: stat.modified,
          ),
        ),
        throwsA(isA<ReportException>()),
      );
      expect(photo.existsSync(), isTrue);
    });

    test('shares the PDF with its MIME type', () async {
      final result = await service().generate(job(1));
      await service().share(result.file);
      expect(shared!.files!.single.mimeType, 'application/pdf');
      expect(shared!.files!.single.path, result.file.path);
    });
  });
}
