import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/core/services/photo_storage_service.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/services/image_processor.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';
import 'package:gps_camera/features/watermark/services/watermark_renderer.dart';
import 'package:image/image.dart' as img;

import 'helpers/test_env.dart';
import 'helpers/watermark_fixtures.dart';

/// Stands in for the GPU rasterizer: a solid blue block at the painter's
/// bounds, so tests can find exactly where the watermark landed.
Future<OverlayBitmap?> solidBlue(WatermarkPainter painter) async {
  final b = painter.bounds;
  final width = b.width.ceil();
  final height = b.height.ceil();
  final rgba = Uint8List(width * height * 4);
  for (var i = 0; i < rgba.length; i += 4) {
    rgba
      ..[i] = 20
      ..[i + 1] = 40
      ..[i + 2] = 230
      ..[i + 3] = 255;
  }
  return OverlayBitmap(
    left: b.left.floor(),
    top: b.top.floor(),
    width: width,
    height: height,
    rgba: rgba,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late PhotoStorageService storage;
  late File original;
  late Uint8List originalBytes;
  const processor = ImageProcessor();

  setUp(() async {
    root = await mockPathProvider();
    storage = PhotoStorageService();
    final photos = await storage.photosDirectory();
    original = writeTestJpeg('${photos.path}/IMG_test.jpg');
    originalBytes = original.readAsBytesSync();
  });

  Future<List<String>> watermarkedFiles() async {
    final dir = await storage.watermarkedDirectory();
    return dir.listSync().map((f) => f.uri.pathSegments.last).toList()..sort();
  }

  WatermarkRenderer renderer({
    Future<OverlayBitmap?> Function(WatermarkPainter)? rasterize,
    ImageProcessor? imageProcessor,
  }) => WatermarkRenderer(
    storage,
    processor: imageProcessor ?? processor,
    rasterize: rasterize ?? solidBlue,
    clock: () => DateTime.utc(2026, 11, 7, 5),
  );

  Future<WatermarkResult> render({
    WatermarkConfig config = const WatermarkConfig(),
    Size size = const Size(400, 300),
    WatermarkRenderer? using,
  }) => (using ?? renderer()).render(
    original: original,
    metadata: fixtureMetadata(),
    config: config,
    imageSize: size,
  );

  group('preview', () {
    test('reports oriented size and keeps aspect ratio', () async {
      final preview = await processor.loadPreview(original.path);
      expect((preview.width, preview.height), (400, 300));
      final decoded = img.decodeJpg(preview.bytes)!;
      expect(decoded.width / decoded.height, closeTo(400 / 300, 0.01));
    });

    test('applies EXIF orientation', () async {
      final rotated = writeTestJpeg('${root.path}/rot.jpg', orientation: 6);
      final preview = await processor.loadPreview(rotated.path);
      expect((preview.width, preview.height), (300, 400));
    });

    test('downscales large photos for the screen', () async {
      final big = writeTestJpeg(
        '${root.path}/big.jpg',
        width: 3200,
        height: 2400,
      );
      final preview = await const ImageProcessor(previewMaxSide: 800)
          .loadPreview(big.path);
      final decoded = img.decodeJpg(preview.bytes)!;
      expect((decoded.width, decoded.height), (800, 600));
      expect((preview.width, preview.height), (3200, 2400));
    });
  });

  group('render', () {
    test(
      'creates a separate watermarked JPEG and leaves the original',
      () async {
        final result = await render();

        expect(original.readAsBytesSync(), originalBytes);
        expect(result.output.path, isNot(original.path));
        expect(result.output.path, contains('/GPSCamera/Watermarked/'));
        expect(result.output.uri.pathSegments.last, 'IMG_test_wm.jpg');

        final output = img.decodeJpg(result.output.readAsBytesSync())!;
        expect((output.width, output.height), (400, 300));

        final painter = WatermarkPainter(
          content: WatermarkContent.from(
            fixtureMetadata(),
            const WatermarkConfig(),
          ),
          config: const WatermarkConfig(),
          imageSize: const Size(400, 300),
        );
        final inside = painter.bounds.center;
        expect(
          isNear(
            output.getPixel(inside.dx.round(), inside.dy.round()),
            20,
            40,
            230,
          ),
          isTrue,
          reason: 'watermark pixels present',
        );
        expect(isNear(output.getPixel(20, 20), 220, 30, 30), isTrue);
        expect(isNear(output.getPixel(300, 40), 128, 128, 128), isTrue);
        painter.dispose();
      },
    );

    test('bakes EXIF orientation into the output', () async {
      original = writeTestJpeg(original.path, orientation: 6);
      originalBytes = original.readAsBytesSync();

      final result = await render(size: const Size(300, 400));
      final output = img.decodeJpg(result.output.readAsBytesSync())!;

      expect((output.width, output.height), (300, 400));
      expect(output.exif.imageIfd.orientation, anyOf(isNull, 1));
      expect(
        isNear(output.getPixel(280, 20), 220, 30, 30),
        isTrue,
        reason: 'top-left red quarter rotated to top-right',
      );
      expect(original.readAsBytesSync(), originalBytes);
    });

    test('writes a record linking output to its original', () async {
      final result = await render(config: const WatermarkConfig(opacity: 0.8));
      final record =
          jsonDecode(result.record.readAsStringSync()) as Map<String, dynamic>;

      expect(
        result.record.path,
        result.output.path.replaceAll('.jpg', '.json'),
      );
      expect(record['sourceImageFileName'], 'IMG_test.jpg');
      expect(record['sourceMetadataFileName'], 'IMG_test.json');
      expect(record['outputFileName'], 'IMG_test_wm.jpg');
      expect(record['renderedAt'], '2026-11-07T05:00:00.000Z');
      expect((record['config'] as Map)['opacity'], 0.8);
      expect(record['schemaVersion'], 2);
      expect(
        ((record['sourceMetadata'] as Map)['location'] as Map)['status'],
        'current',
      );
    });

    test('never overwrites an earlier output', () async {
      final first = await render();
      final firstBytes = first.output.readAsBytesSync();
      final second = await render(
        config: const WatermarkConfig(position: WatermarkPosition.bottomRight),
      );

      expect(second.output.uri.pathSegments.last, 'IMG_test_wm_1.jpg');
      expect(first.output.readAsBytesSync(), firstBytes);
      expect(await watermarkedFiles(), [
        'IMG_test_wm.jpg',
        'IMG_test_wm.json',
        'IMG_test_wm_1.jpg',
        'IMG_test_wm_1.json',
      ]);
    });

    test('skips names taken by unrelated files', () async {
      final dir = await storage.watermarkedDirectory();
      File('${dir.path}/IMG_test_wm.jpg').writeAsStringSync('keep me');
      File('${dir.path}/IMG_test_wm_1.json').writeAsStringSync('{}');

      final result = await render();

      expect(result.output.uri.pathSegments.last, 'IMG_test_wm_2.jpg');
      expect(File('${dir.path}/IMG_test_wm.jpg').readAsStringSync(), 'keep me');
    });

    test('renders a photo with no recorded location', () async {
      final result = await renderer().render(
        original: original,
        metadata: fixtureMetadata(
          location: const LocationSnapshot.unavailable(
            LocationUnavailableReason.noFixYet,
          ),
        ),
        config: const WatermarkConfig(),
        imageSize: const Size(400, 300),
      );
      expect(result.output.existsSync(), isTrue);
    });
  });

  group('failures', () {
    test('a corrupt original fails cleanly and stays untouched', () async {
      original.writeAsBytesSync(utf8.encode('not a jpeg'));
      final before = original.readAsBytesSync();

      await expectLater(render(), throwsA(isA<WatermarkException>()));
      expect(original.readAsBytesSync(), before);
      expect(await watermarkedFiles(), isEmpty);
    });

    test('a size mismatch is rejected without leftovers', () async {
      await expectLater(
        render(size: const Size(800, 600)),
        throwsA(
          isA<WatermarkException>().having(
            (e) => e.message,
            'message',
            contains('changed size'),
          ),
        ),
      );
      expect(await watermarkedFiles(), isEmpty);
      expect(original.readAsBytesSync(), originalBytes);
    });

    test('a drawing failure reserves no output file', () async {
      await expectLater(
        render(using: renderer(rasterize: (_) => throw StateError('gpu'))),
        throwsA(isA<WatermarkException>()),
      );
      expect(await watermarkedFiles(), isEmpty);
    });

    test('oversized photos are refused instead of exhausting memory', () async {
      await expectLater(
        render(
          using: renderer(
            imageProcessor: const ImageProcessor(maxPixels: 1000),
          ),
        ),
        throwsA(isA<WatermarkException>()),
      );
      expect(await watermarkedFiles(), isEmpty);
    });

    test('refuses a watermarked copy as the source', () async {
      final outputs = await storage.watermarkedDirectory();
      original = writeTestJpeg('${outputs.path}/IMG_test_wm.jpg');

      await expectLater(
        render(),
        throwsA(
          isA<WatermarkException>().having(
            (e) => e.message,
            'message',
            contains('already a watermarked copy'),
          ),
        ),
      );
      expect(await watermarkedFiles(), ['IMG_test_wm.jpg']);
    });

    test('nothing selected is refused before any work', () async {
      await expectLater(
        render(
          config: const WatermarkConfig(
            showDate: false,
            showTime: false,
            showCoordinates: false,
            showAccuracy: false,
            showAddress: false,
          ),
        ),
        throwsA(isA<WatermarkException>()),
      );
      expect(await watermarkedFiles(), isEmpty);
    });
  });
}
