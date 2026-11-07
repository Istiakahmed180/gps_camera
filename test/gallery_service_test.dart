import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/services/gallery_scanner.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';

import 'helpers/gallery_fixtures.dart';
import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GalleryFixture fx;
  late GalleryService service;

  setUp(() async {
    fx = GalleryFixture(await mockPathProvider());
    service = GalleryService(PhotoStorageService());
    fx
      ..original('IMG_1')
      ..watermarked('IMG_1', 'IMG_1_wm')
      ..watermarked('IMG_1', 'IMG_1_wm_1')
      ..original('IMG_2');
  });

  GalleryIndex index() => scanGallery(fx.photos.path, fx.outputs.path);

  List<String> files(Directory dir) =>
      dir.listSync().map((f) => f.uri.pathSegments.last).toList()..sort();

  test('scans app storage in the background', () async {
    final scanned = await service.scan();
    expect(scanned.photos, hasLength(4));
  });

  test('dimensions come from the record or the JPEG header', () async {
    final i = index();
    final original = await service.dimensionsOf(i.byId('original/IMG_1.jpg')!);
    final copy = await service.dimensionsOf(
      i.byId('watermarked/IMG_1_wm.jpg')!,
    );
    expect((original!.width, original.height), (400, 300));
    expect((copy!.width, copy.height), (400, 300));
  });

  test('the delete plan lists related watermarked copies', () {
    final i = index();
    final plan = service.planDelete(i.byId('original/IMG_1.jpg')!, i);
    expect(plan.related.map((p) => p.fileName).toSet(), {
      'IMG_1_wm.jpg',
      'IMG_1_wm_1.jpg',
    });
    expect(
      service.planDelete(i.byId('watermarked/IMG_1_wm.jpg')!, i).hasRelated,
      isFalse,
    );
  });

  test('deleting a watermarked copy removes it and its record only', () async {
    final i = index();
    final result = await service.delete(
      service.planDelete(i.byId('watermarked/IMG_1_wm.jpg')!, i),
      includeRelated: false,
    );

    expect(result.isComplete, isTrue);
    expect(result.deleted, ['IMG_1_wm.jpg', 'IMG_1_wm.json']);
    expect(files(fx.outputs), ['IMG_1_wm_1.jpg', 'IMG_1_wm_1.json']);
    expect(files(fx.photos), hasLength(4));
  });

  test('deleting an original can keep its watermarked copies', () async {
    final i = index();
    final result = await service.delete(
      service.planDelete(i.byId('original/IMG_1.jpg')!, i),
      includeRelated: false,
    );

    expect(result.isComplete, isTrue);
    expect(files(fx.photos), ['IMG_2.jpg', 'IMG_2.json']);
    expect(files(fx.outputs), hasLength(4));
    final after = index();
    expect(after.sourceOf(after.byId('watermarked/IMG_1_wm.jpg')!), isNull);
  });

  test('deleting an original with its copies removes all of them', () async {
    final i = index();
    final result = await service.delete(
      service.planDelete(i.byId('original/IMG_1.jpg')!, i),
      includeRelated: true,
    );

    expect(result.isComplete, isTrue);
    expect(result.deleted, hasLength(6));
    expect(files(fx.outputs), isEmpty);
    expect(files(fx.photos), ['IMG_2.jpg', 'IMG_2.json']);
  });

  test(
    'partial failures are reported and keep metadata with its image',
    () async {
      final failing = GalleryService(
        PhotoStorageService(),
        deleteFile: (file) async {
          if (file.path.endsWith('IMG_1_wm_1.jpg')) {
            throw FileSystemException('Permission denied', file.path);
          }
          await file.delete();
        },
      );
      final i = index();
      final result = await failing.delete(
        failing.planDelete(i.byId('original/IMG_1.jpg')!, i),
        includeRelated: true,
      );

      expect(result.isComplete, isFalse);
      expect(result.failures.single.fileName, 'IMG_1_wm_1.jpg');
      expect(result.failures.single.message, 'Permission denied');
      expect(files(fx.outputs), ['IMG_1_wm_1.jpg', 'IMG_1_wm_1.json']);
      expect(files(fx.photos), ['IMG_2.jpg', 'IMG_2.json']);
    },
  );

  test('files already gone count as deleted without errors', () async {
    final i = index();
    File('${fx.outputs.path}/IMG_1_wm.json').deleteSync();
    final result = await service.delete(
      service.planDelete(i.byId('watermarked/IMG_1_wm.jpg')!, i),
      includeRelated: false,
    );
    expect(result.isComplete, isTrue);
    expect(result.deleted, ['IMG_1_wm.jpg']);
  });
}
