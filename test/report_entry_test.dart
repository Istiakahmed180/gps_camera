import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_scanner.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/reports/services/pdf_report_renderer.dart';
import 'package:gps_camera/features/reports/services/report_entry_builder.dart';

import 'helpers/gallery_fixtures.dart';
import 'helpers/watermark_fixtures.dart';

void main() {
  late GalleryFixture fx;

  setUp(() async {
    fx = GalleryFixture(await Directory.systemTemp.createTemp('report'));
  });

  GalleryIndex scan() => scanGallery(fx.photos.path, fx.outputs.path);

  Map<String, String> rows(
    ReportEntry entry, [
    ReportType t = ReportType.project,
  ]) => {
    for (final (label, value, _) in reportEntryRows(entry, t)) label: value,
  };

  group('project entries', () {
    test('one entry per original, oldest first, newest copy alongside', () {
      fx
        ..original('IMG_b', capturedAt: DateTime.utc(2026, 3, 2))
        ..original('IMG_a', capturedAt: DateTime.utc(2026, 1, 2, 9))
        ..watermarked('IMG_a', 'IMG_a_wm', renderedAt: DateTime.utc(2026, 2, 2))
        ..watermarked(
          'IMG_a',
          'IMG_a_wm_1',
          renderedAt: DateTime.utc(2026, 2, 5),
        );

      final entries = ReportEntryBuilder.forProject(scan());

      expect(entries.map((e) => e.fileName), ['IMG_a.jpg', 'IMG_b.jpg']);
      final first = entries.first;
      expect(first.images.map((i) => (i.fileName, i.role)), [
        ('IMG_a.jpg', ReportImageRole.original),
        ('IMG_a_wm_1.jpg', ReportImageRole.watermarked),
      ]);
      expect(first.watermarks.map((w) => w.fileName), [
        'IMG_a_wm_1.jpg',
        'IMG_a_wm.jpg',
      ]);
      expect(first.watermarks.first.config!.template.label, 'Classic');
      expect(entries.last.watermarks, isEmpty);
    });

    test('an empty project has no entries', () {
      expect(ReportEntryBuilder.forProject(GalleryIndex.empty), isEmpty);
    });
  });

  group('selected entries', () {
    late GalleryIndex index;
    GalleryPhoto photo(String id) => index.byId(id)!;

    setUp(() {
      fx
        ..original('IMG_1', capturedAt: DateTime.utc(2026, 1, 2))
        ..watermarked('IMG_1', 'IMG_1_wm')
        ..watermarked('IMG_1', 'IMG_1_wm_1')
        ..watermarked('IMG_1', 'IMG_1_wm_2')
        ..original('IMG_2')
        ..watermarked('IMG_gone', 'IMG_gone_wm');
      index = scan();
    });

    test('an original and its copy give one entry, never two', () {
      final entries = ReportEntryBuilder.forSelection([
        photo('original/IMG_1.jpg'),
        photo('watermarked/IMG_1_wm.jpg'),
        photo('original/IMG_1.jpg'),
      ], index);

      expect(entries, hasLength(1));
      expect(entries.single.images.map((i) => i.role), [
        ReportImageRole.original,
        ReportImageRole.watermarked,
      ]);
    });

    test('a selected copy uses its original metadata', () {
      final entry = ReportEntryBuilder.forSelection([
        photo('watermarked/IMG_1_wm.jpg'),
      ], index).single;

      expect(entry.fileName, 'IMG_1.jpg');
      expect(entry.originalAvailable, isTrue);
      expect(entry.metadata!.capturedAt, DateTime.utc(2026, 1, 2));
      expect(entry.images.single.fileName, 'IMG_1_wm.jpg');
      expect(entry.watermarks, hasLength(3));
    });

    test('a copy whose original was deleted keeps its recorded metadata', () {
      final entry = ReportEntryBuilder.forSelection([
        photo('watermarked/IMG_gone_wm.jpg'),
      ], index).single;

      expect(entry.fileName, 'IMG_gone.jpg');
      expect(entry.originalAvailable, isFalse);
      expect(entry.metadata, isNotNull);
      expect(
        rows(entry, ReportType.selection)['Original file'],
        'IMG_gone.jpg (original deleted)',
      );
    });

    test('extra selected copies are listed, not dropped', () {
      final entry = ReportEntryBuilder.forSelection([
        photo('original/IMG_1.jpg'),
        photo('watermarked/IMG_1_wm.jpg'),
        photo('watermarked/IMG_1_wm_1.jpg'),
        photo('watermarked/IMG_1_wm_2.jpg'),
      ], index).single;

      expect(entry.images, hasLength(2));
      expect(entry.otherSelectedCopies, hasLength(2));
    });

    test('an empty selection has no entries', () {
      expect(ReportEntryBuilder.forSelection(const [], index), isEmpty);
    });

    test('the project of each capture is shown', () {
      final entry = ReportEntryBuilder.forSelection(
        [photo('original/IMG_2.jpg')],
        index,
        projectOf: (_) => null,
      ).single;
      expect(rows(entry, ReportType.selection)['Project'], 'None');
    });
  });

  group('report values match stored metadata exactly', () {
    test('coordinates, accuracy, capture time and altitude', () {
      fx.original(
        'IMG_1',
        capturedAt: DateTime.utc(2026, 11, 7, 5, 12, 22),
        location: LocationSnapshot.current(
          LocationFix(
            latitude: 23.9109107,
            longitude: 90.4010056,
            accuracy: 8.050999641418457,
            timestamp: DateTime.utc(2026, 11, 7, 5, 12, 20),
            altitude: -26.100000381469727,
            altitudeReference: AltitudeReference.wgs84Ellipsoid,
            altitudeAccuracy: 3.6419999599456787,
            heading: 249,
          ),
          const Duration(seconds: 2),
        ),
      );
      final r = rows(ReportEntryBuilder.forProject(scan()).single);

      expect(r['Captured'], '07 Nov 2026 · 11:12 AM (UTC+06:00)');
      expect(r['Location status'], 'Current');
      expect(r['Latitude'], '23.9109107°');
      expect(r['Longitude'], '90.4010056°');
      expect(r['GPS accuracy'], '±8.051 m (Good)');
      expect(r['Fix age'], '2 s before capture');
      expect(
        r['Altitude'],
        '−26.1 m above WGS84 ellipsoid (not sea level), ±3.642 m',
      );
      expect(r['Direction of travel'], '249°');
      expect(r['Watermark'], 'None');
      expect(r.containsKey('Address'), isFalse);
    });

    test('poor, stale and unavailable locations are labelled honestly', () {
      fx
        ..original(
          'IMG_stale',
          location: LocationSnapshot.stale(
            fixtureFix(accuracy: 789.73),
            const Duration(minutes: 3),
          ),
        )
        ..original(
          'IMG_none',
          location: const LocationSnapshot.unavailable(
            LocationUnavailableReason.permissionDenied,
          ),
        );
      final entries = {
        for (final e in ReportEntryBuilder.forProject(scan())) e.fileName: e,
      };

      final stale = rows(entries['IMG_stale.jpg']!);
      expect(stale['Location status'], 'Stale (last known location)');
      expect(stale['GPS accuracy'], '±789.73 m (Poor)');
      expect(stale['Fix age'], '3 min before capture');

      final none = rows(entries['IMG_none.jpg']!);
      expect(none['Location status'], 'Unavailable (permission denied)');
      expect(none['Latitude'], 'Unavailable');
      expect(none['GPS accuracy'], 'Unavailable');
    });

    test('missing or damaged metadata is never guessed', () {
      fx
        ..original('IMG_missing', sidecar: false)
        ..original('IMG_broken', rawSidecar: '{not json');
      final entries = {
        for (final e in ReportEntryBuilder.forProject(scan())) e.fileName: e,
      };

      final missing = rows(entries['IMG_missing.jpg']!);
      expect(missing['Captured'], 'Unavailable');
      expect(missing['Metadata'], 'No metadata was saved for this photo');
      expect(missing.containsKey('Latitude'), isFalse);
      expect(
        rows(entries['IMG_broken.jpg']!)['Metadata'],
        'Metadata file is damaged',
      );
    });

    test('watermark settings come from the render record', () {
      fx
        ..original('IMG_1')
        ..watermarked('IMG_1', 'IMG_1_wm')
        ..watermarked('IMG_1', 'IMG_1_wm_1', rawRecord: 'damaged');
      final r = rows(ReportEntryBuilder.forProject(scan()).single);

      expect(r['Watermark'], startsWith('2 versions'));
      expect(r['Watermark settings'], isNotNull);
    });
  });
}
