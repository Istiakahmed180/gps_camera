import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/features/gallery/models/gallery_filter.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';

GalleryPhoto _photo(String name, GalleryPhotoKind kind, int day) =>
    GalleryPhoto(
      path: '/x/$name',
      kind: kind,
      sizeBytes: 1,
      modifiedAt: DateTime.utc(2026, 1, day),
    );

class _ScriptedService extends GalleryService {
  _ScriptedService() : super(PhotoStorageService());

  final List<Completer<GalleryIndex>> scans = [];

  @override
  Future<GalleryIndex> scan() {
    final completer = Completer<GalleryIndex>();
    scans.add(completer);
    return completer.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  final index = GalleryIndex(
    photos: [
      _photo('a.jpg', GalleryPhotoKind.original, 1),
      _photo('b_wm.jpg', GalleryPhotoKind.watermarked, 2),
      _photo('c.jpg', GalleryPhotoKind.original, 3),
    ],
  );

  test('shows loading, then the photos newest first', () async {
    final service = _ScriptedService();
    final controller = Get.put(GalleryController(service));

    expect(controller.status.value, GalleryStatus.loading);
    service.scans.single.complete(index);
    await pumpEventQueue();

    expect(controller.status.value, GalleryStatus.ready);
    expect(controller.visible.map((p) => p.fileName), [
      'c.jpg',
      'b_wm.jpg',
      'a.jpg',
    ]);
  });

  test('filter and sort update the visible list', () async {
    final service = _ScriptedService();
    final controller = Get.put(GalleryController(service));
    service.scans.single.complete(index);
    await pumpEventQueue();

    controller
      ..setFilter(GalleryFilter.originals)
      ..setSort(GallerySort.oldestFirst);
    expect(controller.visible.map((p) => p.fileName), ['a.jpg', 'c.jpg']);

    controller.setFilter(GalleryFilter.watermarked);
    expect(controller.visible.map((p) => p.fileName), ['b_wm.jpg']);
  });

  test('overlapping reloads never scan concurrently', () async {
    final service = _ScriptedService();
    final controller = Get.put(GalleryController(service));

    final second = controller.reload();
    final third = controller.reload();
    expect(service.scans, hasLength(1), reason: 'one scan at a time');

    service.scans[0].complete(GalleryIndex.empty);
    await Future<void>.delayed(Duration.zero);
    expect(service.scans, hasLength(2), reason: 'one merged follow-up scan');

    service.scans[1].complete(index);
    await Future.wait([second, third]);
    expect(service.scans, hasLength(2));
    expect(controller.index.value.photos, hasLength(3));
  });

  test('an empty gallery is ready, not an error', () async {
    final service = _ScriptedService();
    final controller = Get.put(GalleryController(service));
    service.scans.single.complete(GalleryIndex.empty);
    await pumpEventQueue();

    expect(controller.status.value, GalleryStatus.ready);
    expect(controller.index.value.isEmpty, isTrue);
  });

  test('a failed first scan shows an error state', () async {
    final service = _ScriptedService();
    final controller = Get.put(GalleryController(service));
    service.scans.single.completeError(const FileSystemExceptionStub());
    await pumpEventQueue();

    expect(controller.status.value, GalleryStatus.error);
  });
}

class FileSystemExceptionStub implements Exception {
  const FileSystemExceptionStub();
}
