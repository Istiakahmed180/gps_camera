import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/features/gallery/models/gallery_filter.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_scanner.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';

import 'helpers/gallery_fixtures.dart';
import 'helpers/watermark_fixtures.dart';

void main() {
  late GalleryFixture fx;

  setUp(() async {
    fx = GalleryFixture(await Directory.systemTemp.createTemp('gallery'));
  });

  GalleryIndex scan() => scanGallery(fx.photos.path, fx.outputs.path);

  test('empty folders give an empty gallery', () {
    final index = scan();
    expect(index.isEmpty, isTrue);
    expect(index.count(GalleryFilter.all), 0);
  });

  test('missing folders give an empty gallery', () {
    expect(scanGallery('/no/such/a', '/no/such/b').isEmpty, isTrue);
  });

  test('discovers originals with their metadata', () {
    fx.original('IMG_1', capturedAt: DateTime.utc(2026, 11, 7, 4));
    final photo = scan().photos.single;

    expect(photo.kind, GalleryPhotoKind.original);
    expect(photo.fileName, 'IMG_1.jpg');
    expect(photo.metadata!.capturedAt, DateTime.utc(2026, 11, 7, 4));
    expect(photo.metadata!.location.fix!.accuracy, 6.75);
    expect(photo.sizeBytes, greaterThan(0));
    expect(photo.issue, isNull);
  });

  test('discovers watermarked copies and links them to originals', () {
    fx
      ..original('IMG_1')
      ..watermarked('IMG_1', 'IMG_1_wm')
      ..watermarked('IMG_1', 'IMG_1_wm_1')
      ..original('IMG_2');
    final index = scan();
    final original = index.byId('original/IMG_1.jpg')!;
    final copy = index.byId('watermarked/IMG_1_wm.jpg')!;

    expect(index.count(GalleryFilter.originals), 2);
    expect(index.count(GalleryFilter.watermarked), 2);
    expect(index.variantsOf(original).map((p) => p.fileName).toSet(), {
      'IMG_1_wm.jpg',
      'IMG_1_wm_1.jpg',
    });
    expect(index.sourceOf(copy), same(original));
    expect(copy.record!.config.template.name, 'mapCard');
    expect(index.variantsOf(index.byId('original/IMG_2.jpg')!), isEmpty);
  });

  test('copies keep capture metadata after their original is deleted', () {
    fx.watermarked('IMG_gone', 'IMG_gone_wm');
    final copy = scan().photos.single;

    expect(copy.metadata, isNotNull);
    expect(copy.metadata!.location.fix!.latitude, 23.910908);
    expect(scan().sourceOf(copy), isNull);
  });

  test('older records without embedded metadata use the original sidecar', () {
    fx
      ..original('IMG_1', capturedAt: DateTime.utc(2026, 1, 2, 3))
      ..watermarked('IMG_1', 'IMG_1_wm', embedMetadata: false);
    final copy = scan().byId('watermarked/IMG_1_wm.jpg')!;

    expect(copy.record!.sourceMetadata, isNull);
    expect(copy.metadata!.capturedAt, DateTime.utc(2026, 1, 2, 3));
  });

  test('missing sidecar is listed and flagged', () {
    fx.original('IMG_1', sidecar: false);
    final photo = scan().photos.single;

    expect(photo.metadata, isNull);
    expect(photo.issue, GalleryIssue.metadataMissing);
  });

  test('corrupt sidecar does not affect other photos', () {
    fx
      ..original('IMG_bad', rawSidecar: '{"schemaVersion": 1, "loc')
      ..original('IMG_wrong', rawSidecar: '{"schemaVersion": "x"}')
      ..original('IMG_ok');
    final index = scan();

    expect(index.photos, hasLength(3));
    expect(
      index.byId('original/IMG_bad.jpg')!.issue,
      GalleryIssue.metadataUnreadable,
    );
    expect(
      index.byId('original/IMG_wrong.jpg')!.issue,
      GalleryIssue.metadataUnreadable,
    );
    expect(index.byId('original/IMG_ok.jpg')!.metadata, isNotNull);
  });

  test('a damaged record falls back to the file name for its original', () {
    fx
      ..original('IMG_1')
      ..watermarked('IMG_1', 'IMG_1_wm_2', rawRecord: 'not json');
    final index = scan();
    final copy = index.byId('watermarked/IMG_1_wm_2.jpg')!;

    expect(copy.issue, GalleryIssue.recordUnreadable);
    expect(copy.sourceFileName, 'IMG_1.jpg');
    expect(index.sourceOf(copy)!.fileName, 'IMG_1.jpg');
    expect(copy.metadata, isNotNull, reason: 'from the original sidecar');
  });

  test('missing images are skipped and counted, not shown', () {
    fx.original('IMG_1');
    File('${fx.photos.path}/IMG_orphan.json').writeAsStringSync('{}');
    File('${fx.outputs.path}/IMG_x_wm.json').writeAsStringSync('{}');
    final index = scan();

    expect(index.photos, hasLength(1));
    expect(index.orphanSidecars, 2);
  });

  test('in-progress renders and temp files are ignored', () {
    File('${fx.outputs.path}/IMG_1_wm.jpg').createSync();
    File('${fx.outputs.path}/IMG_1_wm.jpg.tmp').writeAsBytesSync([1, 2, 3]);
    File('${fx.photos.path}/notes.txt').writeAsStringSync('x');

    expect(scan().isEmpty, isTrue);
  });

  test('sorts newest first, oldest first, and filters', () {
    fx
      ..original('IMG_a', capturedAt: DateTime.utc(2026, 1, 2))
      ..original('IMG_b', capturedAt: DateTime.utc(2026, 3, 2))
      ..watermarked('IMG_a', 'IMG_a_wm', renderedAt: DateTime.utc(2026, 2, 2));
    final index = scan();
    String names(List<GalleryPhoto> photos) =>
        photos.map((p) => p.fileName).join(',');

    expect(
      names(index.view(GalleryFilter.all, GallerySort.newestFirst)),
      'IMG_b.jpg,IMG_a_wm.jpg,IMG_a.jpg',
    );
    expect(
      names(index.view(GalleryFilter.all, GallerySort.oldestFirst)),
      'IMG_a.jpg,IMG_a_wm.jpg,IMG_b.jpg',
    );
    expect(
      names(index.view(GalleryFilter.originals, GallerySort.newestFirst)),
      'IMG_b.jpg,IMG_a.jpg',
    );
    expect(
      names(index.view(GalleryFilter.watermarked, GallerySort.oldestFirst)),
      'IMG_a_wm.jpg',
    );
  });

  test('photos without metadata sort by file time', () {
    fx.original('IMG_1', sidecar: false);
    final photo = scan().photos.single;
    expect(photo.savedAt, photo.modifiedAt);
  });

  test('keeps the recorded location status for details', () {
    fx.original(
      'IMG_1',
      location: const LocationSnapshot.unavailable(
        LocationUnavailableReason.locationServicesDisabled,
      ),
    );
    final location = scan().photos.single.metadata!.location;
    expect(location.status, LocationRecordStatus.unavailable);
    expect(location.reason, LocationUnavailableReason.locationServicesDisabled);
  });

  group('helpers', () {
    test('derives the original name from output names', () {
      expect(sourceNameFromOutput('IMG_1_wm.jpg'), 'IMG_1.jpg');
      expect(sourceNameFromOutput('IMG_1_wm_12.jpg'), 'IMG_1.jpg');
      expect(sourceNameFromOutput('IMG_1.jpg'), isNull);
    });

    test('reads dimensions from the header, honouring EXIF rotation', () {
      final plain = writeTestJpeg('${fx.root.path}/a.jpg');
      final rotated = writeTestJpeg('${fx.root.path}/b.jpg', orientation: 6);
      final dims = readJpegDimensions(plain.path)!;
      final rotatedDims = readJpegDimensions(rotated.path)!;

      expect((dims.width, dims.height), (400, 300));
      expect((rotatedDims.width, rotatedDims.height), (300, 400));
      File('${fx.root.path}/c.jpg').writeAsStringSync('nope');
      expect(readJpegDimensions('${fx.root.path}/c.jpg'), isNull);
    });
  });
}
