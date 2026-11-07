import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/services/static_map_service.dart';
import 'package:gps_camera/features/reports/models/report_map.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/reports/services/pdf_report_renderer.dart';
import 'package:gps_camera/features/reports/services/report_service.dart';
import 'package:image/image.dart' as img;

import 'helpers/gallery_fixtures.dart';
import 'helpers/report_fixtures.dart';
import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

PhotoMetadata _at(double lat, double lng) => fixtureMetadata(
  location: LocationSnapshot.current(
    testFix(latitude: lat, longitude: lng),
    Duration.zero,
  ),
);

ReportEntry _entry(String name, PhotoMetadata? metadata, {String? dir}) =>
    ReportEntry(
      fileName: name,
      originalAvailable: true,
      images: [
        ReportImage(
          path: '${dir ?? '/x'}/$name',
          fileName: name,
          role: ReportImageRole.original,
        ),
      ],
      metadata: metadata,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pins', () {
    test('nearby photos share a pin labelled with the first number', () {
      final pins = ReportMapPins.from([
        _entry('a.jpg', _at(23.91091, 90.40100)),
        _entry('b.jpg', _at(23.80000, 90.40000)),
        _entry('c.jpg', _at(23.91093, 90.40101)), // ~2 m from a
        _entry('d.jpg', null),
        _entry(
          'e.jpg',
          fixtureMetadata(
            location: const LocationSnapshot.unavailable(
              LocationUnavailableReason.noFixYet,
            ),
          ),
        ),
      ]);
      expect(pins.map((p) => p.label), [1, 2]);
      expect(pins.first.entries, [1, 3]);
      expect(pins.last.entries, [2]);
    });
  });

  group('fit', () {
    ReportMapPin pin(double lat, double lng) =>
        ReportMapPin(label: 1, latitude: lat, longitude: lng, entries: [1]);

    test('one spot is shown close up', () {
      final fit = MapFit.of([pin(23.91, 90.40)], width: 600, height: 360);
      expect(fit.zoom, 17);
      expect(fit.latitude, closeTo(23.91, 1e-6));
      expect(fit.longitude, closeTo(90.40, 1e-6));
    });

    test('spread-out spots are centred and zoomed out to fit', () {
      final near = MapFit.of(
        [pin(23.91, 90.40), pin(23.92, 90.41)],
        width: 600,
        height: 360,
      );
      final far = MapFit.of(
        [pin(23.7, 90.4), pin(22.3, 91.8)], // Dhaka – Chattogram
        width: 600,
        height: 360,
      );
      expect(near.zoom, greaterThan(far.zoom));
      expect(far.zoom, inInclusiveRange(6, 9));
      expect(near.longitude, closeTo(90.405, 1e-6));
      expect(near.latitude, closeTo(23.915, 1e-3));
    });

    test('the map URL numbers each pin', () {
      final url = StaticMapService('KEY').overviewUrl([
        const ReportMapPin(
          label: 1,
          latitude: 23.91,
          longitude: 90.40,
          entries: [1, 2],
        ),
        const ReportMapPin(
          label: 3,
          latitude: 23.80,
          longitude: 90.41,
          entries: [3],
        ),
      ]);
      final marker = url.queryParameters['marker']!;
      expect(marker.split('|'), hasLength(2));
      expect(marker, contains('lonlat:90.400000,23.910000'));
      expect(marker, endsWith('text:3'));
      expect(url.queryParameters['zoom'], isNotNull);
    });
  });

  group('in the report', () {
    late GalleryFixture fx;
    late PhotoStorageService storage;

    setUp(() async {
      fx = GalleryFixture(await mockPathProvider());
      fx
        ..original('IMG_1')
        ..original('IMG_2');
      storage = PhotoStorageService();
    });

    ReportJob job() => ReportJob(
      type: ReportType.project,
      title: 'Map test',
      generatedAt: DateTime(2026, 11, 7, 12),
      entries: [
        _entry('IMG_1.jpg', _at(23.91, 90.40), dir: fx.photos.path),
        _entry('IMG_2.jpg', _at(23.80, 90.41), dir: fx.photos.path),
      ],
    );

    ReportService service(OverviewMapFetcher fetch, List<ReportJob> seen) =>
        ReportService(
          storage,
          ShareService(),
          fonts: () async => testReportFonts(),
          overviewMap: fetch,
          runner: (job, fonts, path, onProgress) async {
            seen.add(job);
            return renderReportPdf(job, fonts, path);
          },
        );

    final png = img.encodePng(img.Image(width: 60, height: 36));

    test('adds the map and its pins when online', () async {
      final seen = <ReportJob>[];
      List<ReportMapPin>? asked;
      final result = await service((pins) async {
        asked = pins;
        return png;
      }, seen).generate(job());

      expect(asked!.map((p) => p.label), [1, 2]);
      expect(seen.single.map!.image, png);
      expect(seen.single.mapUnavailable, isFalse);
      expect(looksLikePdf(result.file), isTrue);

      final plain = await service(
        (_) async => png,
        [],
      ).generate(job().withMap(null, unavailable: false));
      expect(result.file.lengthSync(), greaterThan(0));
      expect(plain.file.existsSync(), isTrue);
    });

    test(
      'offline: the report is still made and says why there is no map',
      () async {
        final seen = <ReportJob>[];
        final result = await service((_) async => null, seen).generate(job());
        expect(seen.single.map, isNull);
        expect(seen.single.mapUnavailable, isTrue);
        expect(looksLikePdf(result.file), isTrue);
      },
    );

    test('a hanging map request never blocks the report', () async {
      final seen = <ReportJob>[];
      final never = Completer<Uint8List?>();
      final result = await service((_) => never.future, seen)
          .generate(job())
          .timeout(ReportService.mapTimeout + const Duration(seconds: 5));
      expect(seen.single.mapUnavailable, isTrue);
      expect(result.file.existsSync(), isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('photos without a location never ask for a map', () async {
      var asked = false;
      final seen = <ReportJob>[];
      await service((_) async {
        asked = true;
        return png;
      }, seen).generate(
        ReportJob(
          type: ReportType.project,
          title: 'No GPS',
          generatedAt: DateTime(2026, 11, 7),
          entries: [_entry('IMG_1.jpg', null, dir: fx.photos.path)],
        ),
      );
      expect(asked, isFalse);
      expect(seen.single.mapUnavailable, isFalse);
      expect(File('${fx.photos.path}/IMG_1.jpg').existsSync(), isTrue);
    });
  });
}
