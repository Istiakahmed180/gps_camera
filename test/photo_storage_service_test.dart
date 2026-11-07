import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';

import 'helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  final service = PhotoStorageService();
  final capturedAt = DateTime(2026, 11, 7, 9, 5, 3, 42);

  setUp(() async => root = await mockPathProvider());

  Future<XFile> fakeCapture(String name) async {
    final file = File('${root.path}/$name');
    await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
    return XFile(file.path);
  }

  test('saves into GPSCamera/Photos with a timestamped name', () async {
    final capture = await fakeCapture('cache_1.jpg');
    final saved = await service.savePhoto(capture, capturedAt: capturedAt);

    expect(
      saved.path,
      '${root.path}/GPSCamera/Photos/IMG_20261107_090503_042.jpg',
    );
    expect(await saved.readAsBytes(), [0xFF, 0xD8, 0xFF, 0xD9]);
    expect(await File(capture.path).exists(), isFalse);
  });

  test('never overwrites a photo with the same timestamp', () async {
    final first = await service.savePhoto(
      await fakeCapture('cache_1.jpg'),
      capturedAt: capturedAt,
    );
    final second = await service.savePhoto(
      await fakeCapture('cache_2.jpg'),
      capturedAt: capturedAt,
    );

    expect(second.path, isNot(first.path));
    expect(second.path, endsWith('IMG_20261107_090503_042_1.jpg'));
    expect(await first.exists(), isTrue);
    expect(await second.exists(), isTrue);
  });

  test('rejects an empty capture', () async {
    final empty = File('${root.path}/empty.jpg')..writeAsBytesSync([]);

    expect(
      () => service.savePhoto(XFile(empty.path), capturedAt: capturedAt),
      throwsA(isA<FileSystemException>()),
    );
  });
}
