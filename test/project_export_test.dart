import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/projects/services/project_export_service.dart';
import 'package:image/image.dart' as img;

import 'helpers/gallery_fixtures.dart';
import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late GalleryFixture fx;
  late GalleryIndex index;
  late Directory temp;

  setUp(() async {
    root = await mockPathProvider();
    fx = GalleryFixture(root);
    fx
      ..original('IMG_1', capturedAt: DateTime.utc(2026, 11, 1, 4))
      ..watermarked('IMG_1', 'IMG_1_wm')
      ..original('IMG_2', capturedAt: DateTime.utc(2026, 11, 2, 4))
      ..watermarked('IMG_GONE', 'IMG_GONE_wm');
    index = await GalleryService(PhotoStorageService()).scan();
    temp = await Directory.systemTemp.createTemp('zip_cache');
  });

  ProjectExportService service() => ProjectExportService(
    tempDirectory: () async => temp,
    clock: () => DateTime(2026, 11, 8, 10),
  );

  List<String> names(List<dynamic> photos) => [
    for (final p in photos) p.fileName as String,
  ];

  test('plans each choice', () {
    expect(
      names(ProjectExportService.plan(index, ProjectZipContents.originals)),
      ['IMG_1.jpg', 'IMG_2.jpg'],
    );
    expect(
      names(ProjectExportService.plan(index, ProjectZipContents.watermarked)),
      ['IMG_1_wm.jpg', 'IMG_2.jpg', 'IMG_GONE_wm.jpg'],
    );
    expect(names(ProjectExportService.plan(index, ProjectZipContents.both)), [
      'IMG_1.jpg',
      'IMG_1_wm.jpg',
      'IMG_2.jpg',
      'IMG_GONE_wm.jpg',
    ]);
  });

  test('builds a ZIP with photos and a CSV; app files untouched', () async {
    final before = {
      for (final f in fx.photos.listSync().whereType<File>())
        f.path: f.readAsBytesSync(),
    };
    final s = service();
    final zip = await s.build(
      projectName: 'Site C / Block 2',
      index: index,
      contents: ProjectZipContents.both,
    );
    expect(zip.name, 'Site C _ Block 2_photos_20261108.zip');
    expect(zip.photoCount, 4);
    expect(s.isBusy.value, isFalse);

    final archive = ZipDecoder().decodeBytes(zip.file.readAsBytesSync());
    expect(archive.files.map((f) => f.name).toList()..sort(), [
      'IMG_1.jpg',
      'IMG_1_wm.jpg',
      'IMG_2.jpg',
      'IMG_GONE_wm.jpg',
      'photo_locations.csv',
    ]);

    // Originals in the ZIP carry GPS; the app's own originals do not change.
    final exif = img.decodeJpgExif(archive.find('IMG_1.jpg')!.readBytes()!)!;
    expect(exif.gpsIfd.containsKey(0x02), isTrue);
    // Older copies without GPS get it too.
    final copy = img.decodeJpgExif(archive.find('IMG_1_wm.jpg')!.readBytes()!)!;
    expect(copy.gpsIfd.containsKey(0x02), isTrue);
    expect(copy.imageIfd.orientation, 1);
    for (final e in before.entries) {
      expect(File(e.key).readAsBytesSync(), e.value);
    }

    final csv = utf8.decode(archive.find('photo_locations.csv')!.readBytes()!);
    final raw = archive.find('photo_locations.csv')!.readBytes()!;
    expect(raw.take(3), [0xEF, 0xBB, 0xBF], reason: 'UTF-8 byte-order mark');
    expect(
      csv.replaceFirst('\uFEFF', ''),
      startsWith('File,Type,Taken (local)'),
    );
    final lines = csv.trim().split('\r\n');
    expect(lines, hasLength(5));
    expect(
      lines[1],
      startsWith('IMG_1.jpg,Original,2026-11-01 10:00:00,UTC+06:00'),
    );
  });

  test('can leave out the CSV and replaces the previous export', () async {
    final first = await service().build(
      projectName: 'A',
      index: index,
      contents: ProjectZipContents.originals,
    );
    final second =
        await ProjectExportService(
          tempDirectory: () async => temp,
          clock: () => DateTime(2026, 11, 9),
        ).build(
          projectName: 'A',
          index: index,
          contents: ProjectZipContents.originals,
          includeCsv: false,
        );
    expect(first.file.existsSync(), isFalse);
    final archive = ZipDecoder().decodeBytes(second.file.readAsBytesSync());
    expect(archive.find(ProjectExportService.csvName), isNull);
  });

  test('CSV cells are quoted and never run as formulas', () {
    final csv = ProjectExportService.csvFor(
      ProjectExportService.plan(index, ProjectZipContents.originals),
    );
    expect(csv, isNot(contains('\n=')));
    expect(
      ProjectExportService.fileNameFor('  ', DateTime(2026)),
      'Project_photos_20260101.zip',
    );
  });

  test('an empty project is refused', () async {
    await expectLater(
      service().build(
        projectName: 'Empty',
        index: GalleryIndex.empty,
        contents: ProjectZipContents.both,
      ),
      throwsA(isA<ProjectExportException>()),
    );
  });
}
