import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/core/services/storage_service.dart';
import 'package:gps_camera/features/watermark/controllers/watermark_controller.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_template.dart';
import 'package:gps_camera/features/watermark/services/image_processor.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';

import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PhotoStorageService storage;
  late WatermarkSettingsStore settings;
  late File photo;
  var rasterCalls = 0;

  Future<OverlayBitmap?> countingRasterizer(WatermarkPainter painter) async {
    rasterCalls++;
    final b = painter.bounds;
    final w = b.width.ceil();
    final h = b.height.ceil();
    return OverlayBitmap(
      left: b.left.floor(),
      top: b.top.floor(),
      width: w,
      height: h,
      rgba: Uint8List(w * h * 4),
    );
  }

  setUpAll(() async {
    await mockPathProvider();
    await GetStorage.init('watermark_controller_test');
  });

  setUp(() async {
    rasterCalls = 0;
    storage = PhotoStorageService();
    final box = GetStorage('watermark_controller_test');
    await box.erase();
    settings = WatermarkSettingsStore(StorageService(box));
    final photos = await storage.photosDirectory();
    photo = writeTestJpeg('${photos.path}/IMG_ctrl.jpg');
    await storage.saveMetadata(photo, fixtureMetadata().toJson());
  });

  tearDown(Get.reset);

  WatermarkController build({File? file}) {
    final controller = WatermarkController(
      photo: file ?? photo,
      storage: storage,
      renderer: WatermarkRenderer(storage, rasterize: countingRasterizer),
      settings: settings,
    );
    return Get.put(controller);
  }

  Future<void> loaded(WatermarkController c) async {
    while (c.status.value == WatermarkEditorStatus.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('loads the photo, its metadata and saved settings', () async {
    await settings.save(
      const WatermarkConfig(template: WatermarkTemplate.minimal),
    );
    final controller = build();
    await loaded(controller);

    expect(controller.status.value, WatermarkEditorStatus.ready);
    expect(controller.preview.value!.width, 400);
    expect(controller.content!.date, '07 Nov 2026');
    expect(controller.config.value.template, WatermarkTemplate.minimal);
    expect(controller.canSave, isTrue);
  });

  test(
    'a photo without metadata shows an error, not a fake watermark',
    () async {
      final photos = await storage.photosDirectory();
      final bare = writeTestJpeg('${photos.path}/IMG_bare.jpg');
      final controller = build(file: bare);
      await loaded(controller);

      expect(controller.status.value, WatermarkEditorStatus.error);
      expect(controller.loadError.value, contains('no metadata'));
      expect(controller.canSave, isFalse);
    },
  );

  test('a damaged sidecar is reported', () async {
    storage.metadataFileFor(photo).writeAsStringSync('{not json');
    final controller = build();
    await loaded(controller);

    expect(controller.loadError.value, contains('damaged'));
  });

  test('changes persist and a double tap renders only once', () async {
    final controller = build();
    await loaded(controller);

    controller.updateConfig(
      controller.config.value.copyWith(position: WatermarkPosition.bottomRight),
    );
    expect(settings.load().position, WatermarkPosition.bottomRight);

    final first = controller.save();
    expect(controller.isSaving.value, isTrue);
    expect(controller.canSave, isFalse);
    await controller.save();
    await first;

    expect(rasterCalls, 1);
    expect(controller.lastResult.value!.output.existsSync(), isTrue);
    expect(controller.isSaving.value, isFalse);
  });

  test('render failures are shown and saving can be retried', () async {
    final controller = build();
    await loaded(controller);
    photo.writeAsStringSync('corrupted after opening');

    await controller.save();

    expect(controller.saveError.value, isNotNull);
    expect(controller.lastResult.value, isNull);
    expect(controller.canSave, isTrue);
  });

  test('a watermarked copy can never be opened as a source', () async {
    final outputs = await storage.watermarkedDirectory();
    final copy = writeTestJpeg('${outputs.path}/IMG_ctrl_wm.jpg');
    final controller = build(file: copy);
    await loaded(controller);

    expect(controller.status.value, WatermarkEditorStatus.error);
    expect(controller.loadError.value, contains('watermarked copy'));
    expect(controller.canSave, isFalse);
    expect(rasterCalls, 0);
  });
}
