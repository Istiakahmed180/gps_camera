import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/models/photo_search.dart';
import 'package:gps_camera/features/gallery/models/photo_spots.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/location/models/place_info.dart';
import 'package:share_plus/share_plus.dart';

import 'helpers/db_fixtures.dart';
import 'helpers/gallery_fixtures.dart';
import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

PlaceInfo _tongi() => PlaceInfo(
  latitude: 23.9109,
  longitude: 90.4010,
  plusCode: '7MMGWC62+9C6',
  resolvedAt: DateTime.utc(2026, 11, 7),
  addressLine: 'WC62+8CJ, Bonomala Road, Tongi, Bangladesh',
  locality: 'Tongi',
  country: 'Bangladesh',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('search', () {
    final photo = GalleryPhoto(
      path: '/x/IMG_1.jpg',
      kind: GalleryPhotoKind.original,
      sizeBytes: 1,
      modifiedAt: DateTime.utc(2026),
      metadata: fixtureMetadata()
          .withPlace(place: _tongi())
          .withNote('Crack on Pillar 3'),
    );

    bool find(String q, {String? project}) =>
        PhotoSearch.matches(photo, PhotoSearch.words(q), projectName: project);

    test('matches note, place, address, Plus Code, date and file name', () {
      expect(find(''), isTrue);
      expect(find('pillar'), isTrue);
      expect(find('TONGI  crack'), isTrue, reason: 'any order, any case');
      expect(find('bonomala'), isTrue);
      expect(find('wc62'), isTrue);
      expect(find('07 nov'), isTrue);
      expect(find('img_1'), isTrue);
      expect(find('site c', project: 'Site C'), isTrue);
      expect(find('dhaka pillar'), isFalse, reason: 'every word must match');
      expect(find('gazipur'), isFalse);
    });
  });

  group('map spots', () {
    GalleryPhoto at(
      String name,
      double lat,
      double lng, {
      GalleryPhotoKind kind = GalleryPhotoKind.original,
      String? source,
      bool located = true,
      int day = 1,
    }) => GalleryPhoto(
      path: '/x/$name',
      kind: kind,
      sizeBytes: 1,
      modifiedAt: DateTime.utc(2026, 1, day),
      sourceFileName: source,
      metadata: fixtureMetadata(
        capturedAt: DateTime.utc(2026, 1, day),
        location: located
            ? LocationSnapshot.current(
                testFix(latitude: lat, longitude: lng),
                Duration.zero,
              )
            : const LocationSnapshot.unavailable(
                LocationUnavailableReason.noFixYet,
              ),
      ),
    );

    test('photos a few metres apart share one pin', () {
      // 23.91094 and 23.91096 round to different 4-decimal cells but are
      // only about 2 m apart.
      final spots = PhotoSpots.from([
        at('a.jpg', 23.91094, 90.40101),
        at('b.jpg', 23.91096, 90.40101, day: 2),
        at('far.jpg', 23.91200, 90.40101, day: 3),
      ]);
      expect(spots.map((s) => s.photos.length), [1, 2]);
    });

    test('groups nearby captures and skips copies of shown originals', () {
      final spots = PhotoSpots.from([
        at('a.jpg', 23.91091, 90.40101),
        at('b.jpg', 23.91092, 90.40102, day: 3),
        at(
          'a_wm.jpg',
          23.91091,
          90.40101,
          kind: GalleryPhotoKind.watermarked,
          source: 'a.jpg',
        ),
        at(
          'gone_wm.jpg',
          23.80000,
          90.40000,
          kind: GalleryPhotoKind.watermarked,
          source: 'gone.jpg',
        ),
        at('nogps.jpg', 0, 0, located: false),
      ]);
      expect(spots, hasLength(2));
      final tongi = spots.firstWhere((s) => s.point.latitude > 23.9);
      expect(tongi.photos.map((p) => p.fileName), ['b.jpg', 'a.jpg']);
      final other = spots.firstWhere((s) => s.point.latitude < 23.9);
      expect(other.photos.single.fileName, 'gone_wm.jpg');
    });
  });

  group('selection', () {
    late GalleryFixture files;
    late DbFixture db;
    late GalleryController gallery;

    setUp(() async {
      files = GalleryFixture(await mockPathProvider());
      files
        ..original('IMG_1', capturedAt: DateTime.utc(2025, 12, 31))
        ..watermarked('IMG_1', 'IMG_1_wm')
        ..original('IMG_2', capturedAt: DateTime.utc(2026, 1, 2))
        ..watermarked('IMG_2', 'IMG_2_wm');
      db = DbFixture();
      gallery = Get.put(
        GalleryController(GalleryService(PhotoStorageService()), db.repo),
      );
      await gallery.reload();
    });

    tearDown(() => db.close());

    GalleryPhoto byName(String name) =>
        gallery.index.value.photos.firstWhere((p) => p.fileName == name);

    List<String> left() =>
        gallery.index.value.photos.map((p) => p.fileName).toList()..sort();

    test('deletes selected originals with their copies', () async {
      final site = await db.repo.create(name: 'Site');
      await db.repo.assign('Photos/IMG_1.jpg', site.id);
      gallery
        ..startSelection(byName('IMG_1.jpg'))
        ..toggleSelection(byName('IMG_1_wm.jpg'));
      expect(gallery.selectedWithCopies, 0, reason: 'its copy is selected');

      final results = await gallery.deleteSelected(includeRelated: true);
      expect(results.expand((r) => r.removedPhotos), hasLength(2));
      expect(left(), ['IMG_2.jpg', 'IMG_2_wm.jpg']);
      expect(File('${files.photos.path}/IMG_1.json').existsSync(), isFalse);
      expect(await db.repo.photoRefsOf(site.id), isEmpty);
      expect(gallery.selecting.value, isFalse);
    });

    test('can keep the copies of deleted originals', () async {
      gallery.startSelection(byName('IMG_2.jpg'));
      expect(gallery.selectedWithCopies, 1);
      await gallery.deleteSelected(includeRelated: false);
      expect(left(), ['IMG_1.jpg', 'IMG_1_wm.jpg', 'IMG_2_wm.jpg']);
    });

    test('search narrows what is shown and selectable', () async {
      final photo = files.original(
        'IMG_3',
        capturedAt: DateTime.utc(2026, 1, 3),
      );
      final sidecar = File(photo.path.replaceAll('.jpg', '.json'));
      await GalleryService(PhotoStorageService()).updateNote(
        (await GalleryService(
          PhotoStorageService(),
        ).scan()).photos.firstWhere((p) => p.fileName == 'IMG_3.jpg'),
        'North gate',
      );
      expect(sidecar.readAsStringSync(), contains('North gate'));
      await gallery.reload();

      gallery
        ..startSearch()
        ..setQuery('north');
      expect(gallery.visible.map((p) => p.fileName), ['IMG_3.jpg']);
      gallery.startSelection();
      gallery.selectAllVisible();
      expect(gallery.selectedIds, {'original/IMG_3.jpg'});

      gallery.stopSearch();
      expect(gallery.query.value, '');
      expect(gallery.visible, hasLength(5));
    });
  });

  test('shareImages sends every existing photo in one sheet', () async {
    final root = await mockPathProvider();
    final a = File('${root.path}/a.jpg')..writeAsBytesSync([1]);
    final b = File('${root.path}/b.jpg')..writeAsBytesSync([2]);
    ShareParams? sent;
    final share = ShareService(
      share: (params) async {
        sent = params;
        return const ShareResult('ok', ShareResultStatus.success);
      },
    );
    expect(
      await share.shareImages([a, File('${root.path}/missing.jpg'), b]),
      ShareOutcome.shared,
    );
    expect(sent!.files!.map((f) => f.name), ['a.jpg', 'b.jpg']);
    expect(
      await share.shareImages([File('${root.path}/missing.jpg')]),
      ShareOutcome.missingFile,
    );
  });
}
