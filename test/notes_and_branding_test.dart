import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/camera/models/photo_metadata.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/reports/services/pdf_report_renderer.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/models/watermark_template.dart';
import 'package:gps_camera/features/watermark/services/logo_service.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';
import 'package:image/image.dart' as img;

import 'helpers/gallery_fixtures.dart';
import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

Future<ui.Image> _image(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = Colors.red,
  );
  return recorder.endRecording().toImage(w, h);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('photo note', () {
    test('is cleaned, limited and optional in the sidecar', () {
      expect(
        PhotoMetadata.cleanNote('  Crack   on\npillar 3 '),
        'Crack on pillar 3',
      );
      expect(PhotoMetadata.cleanNote('   '), isNull);
      expect(
        PhotoMetadata.cleanNote('x' * 400)!.length,
        PhotoMetadata.maxNoteLength,
      );

      final plain = fixtureMetadata();
      expect(plain.toJson().containsKey('note'), isFalse);

      final noted = plain.withNote('Gate B');
      final json = noted.toJson();
      expect(json['note'], 'Gate B');
      expect(PhotoMetadata.fromJson(json).note, 'Gate B');

      // Everything else is untouched.
      final without = Map.of(json)..remove('note');
      expect(jsonEncode(without), jsonEncode(plain.toJson()));
      expect(noted.withNote('').note, isNull);
      expect(noted.withPlace().note, 'Gate B', reason: 'kept by withPlace');
    });

    test('updateNote changes only the note of an original', () async {
      final files = GalleryFixture(await mockPathProvider());
      final photo = files.original('IMG_1');
      final sidecar = File(photo.path.replaceAll('.jpg', '.json'));
      final before = jsonDecode(sidecar.readAsStringSync()) as Map;
      final service = GalleryService(PhotoStorageService());
      final index = await service.scan();
      final original = index.photos.single;

      expect(await service.updateNote(original, '  Roof leak '), 'Roof leak');
      final after = jsonDecode(sidecar.readAsStringSync()) as Map;
      expect(after['note'], 'Roof leak');
      expect(Map.of(after)..remove('note'), before);
      expect(photo.existsSync(), isTrue);

      expect(await service.updateNote(original, null), isNull);
      expect(
        (jsonDecode(sidecar.readAsStringSync()) as Map).containsKey('note'),
        isFalse,
      );
    });

    test('reports show the note', () {
      final entry = ReportEntry(
        fileName: 'IMG_1.jpg',
        originalAvailable: true,
        images: const [],
        metadata: fixtureMetadata().withNote('Pillar 3'),
      );
      final rows = {
        for (final (l, v, _) in reportEntryRows(entry, ReportType.project))
          l: v,
      };
      expect(rows['Note'], 'Pillar 3');
    });
  });

  group('branding config', () {
    test('defaults keep old saved settings looking the same', () {
      final old = WatermarkConfig.fromJson({'template': 'map'});
      expect(old.brandText, 'GPS CAMERA');
      expect(old.customText, '');
      expect(old.showLogo, isFalse);
      expect(old.showNote, isTrue);
    });

    test('text is trimmed, limited and round-trips', () {
      final config = const WatermarkConfig().copyWith(
        brandText: '  TDEVS   SURVEY ',
        customText: 'y' * 200,
        showLogo: true,
        showNote: false,
      );
      expect(config.brandText, 'TDEVS SURVEY');
      expect(config.customText.length, WatermarkConfig.maxCustomTextLength);
      expect(WatermarkConfig.fromJson(config.toJson()), config);
      expect(const WatermarkConfig().copyWith(brandText: '').brandText, '');
    });

    test('content carries heading, extra line and note', () {
      final metadata = fixtureMetadata().withNote('North wall');
      final content = WatermarkContent.from(
        metadata,
        const WatermarkConfig(brandText: 'ACME', customText: 'Site C'),
      );
      expect(content.brand, 'ACME');
      expect(content.customText, 'Site C');
      expect(content.note, 'North wall');

      final hidden = WatermarkContent.from(
        metadata,
        const WatermarkConfig(brandText: '', showNote: false),
      );
      expect(hidden.brand, isNull);
      expect(hidden.note, isNull);
    });

    test('a note alone is enough to save a watermark', () {
      final content = WatermarkContent.from(
        fixtureMetadata().withNote('Only this'),
        const WatermarkConfig(
          showDate: false,
          showTime: false,
          showCoordinates: false,
          showAccuracy: false,
          showAddress: false,
        ),
      );
      expect(content.isEmpty, isFalse);
    });
  });

  group('painter', () {
    const size = Size(2000, 1500);

    WatermarkPainter paint(
      WatermarkConfig config, {
      String? note,
      ui.Image? logo,
    }) {
      final metadata = note == null
          ? fixtureMetadata()
          : fixtureMetadata().withNote(note);
      return WatermarkPainter(
        content: WatermarkContent.from(metadata, config),
        config: config,
        imageSize: size,
        logoImage: logo,
      );
    }

    test('extra line and note add rows; empty heading removes one', () {
      for (final template in WatermarkTemplate.values) {
        final base = WatermarkConfig(template: template);
        final plain = paint(base);
        final extra = paint(base.copyWith(customText: 'Site C'), note: 'Gate');
        expect(
          extra.bounds.height,
          greaterThan(plain.bounds.height),
          reason: template.name,
        );
        if (template != WatermarkTemplate.minimal) {
          final noHeading = paint(base.copyWith(brandText: ''));
          expect(
            noHeading.bounds.height,
            lessThan(plain.bounds.height),
            reason: template.name,
          );
          noHeading.dispose();
        }
        expect(
          size.contains(extra.bounds.bottomRight - const Offset(1, 1)),
          isTrue,
        );
        plain.dispose();
        extra.dispose();
      }
    });

    test('the logo widens the heading only when enabled', () async {
      final logo = await _image(300, 100);
      const config = WatermarkConfig(
        showDate: false,
        showTime: false,
        showCoordinates: false,
        showAccuracy: false,
        showAddress: false,
      );
      final noted = fixtureMetadata().withNote('n');
      WatermarkPainter make(WatermarkConfig c, ui.Image? l) => WatermarkPainter(
        content: WatermarkContent.from(noted, c),
        config: c,
        imageSize: size,
        logoImage: l,
      );
      final off = make(config, logo);
      final on = make(config.copyWith(showLogo: true), logo);
      final missing = make(config.copyWith(showLogo: true), null);
      expect(on.bounds.width, greaterThan(off.bounds.width));
      expect(missing.bounds.width, off.bounds.width);

      final recorder = ui.PictureRecorder();
      on.paint(Canvas(recorder));
      recorder.endRecording().dispose();
      for (final p in [off, on, missing]) {
        p.dispose();
      }
      logo.dispose();
    });
  });

  group('logo service', () {
    late Directory root;
    late LogoService service;

    setUp(() async {
      root = await mockPathProvider();
      service = LogoService(PhotoStorageService());
    });

    File source(String name, List<int> bytes) =>
        File('${root.path}/$name')..writeAsBytesSync(bytes);

    test('stores a scaled-down PNG and removes it', () async {
      final big = img.Image(width: 1600, height: 800);
      await service.setFrom(source('logo.jpg', img.encodeJpg(big)));

      final stored = File('${root.path}/GPSCamera/Branding/logo.png');
      final decoded = img.decodePng(stored.readAsBytesSync())!;
      expect(decoded.width, LogoService.maxSide);
      expect(decoded.height, LogoService.maxSide ~/ 2);
      expect(await PhotoStorageService().readLogo(), isNotNull);

      await service.remove();
      expect(stored.existsSync(), isFalse);
      expect(await PhotoStorageService().readLogo(), isNull);
    });

    test('keeps small logos at their size and rejects non-images', () async {
      await service.setFrom(
        source('small.png', img.encodePng(img.Image(width: 120, height: 60))),
      );
      final stored = File('${root.path}/GPSCamera/Branding/logo.png');
      expect(img.decodePng(stored.readAsBytesSync())!.width, 120);

      await expectLater(
        service.setFrom(source('notes.txt', utf8.encode('not an image'))),
        throwsA(isA<LogoException>()),
      );
      expect(
        img.decodePng(stored.readAsBytesSync())!.width,
        120,
        reason: 'a failed pick keeps the old logo',
      );
    });
  });
}
