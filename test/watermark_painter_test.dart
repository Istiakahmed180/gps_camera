import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/models/watermark_template.dart';
import 'package:gps_camera/features/watermark/services/overlay_rasterizer.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';

import 'helpers/watermark_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const image = Size(1080, 1920);
  final content = WatermarkContent.from(
    fixtureMetadata(),
    const WatermarkConfig(),
  );

  WatermarkPainter painterFor(
    WatermarkConfig config, {
    Size size = image,
    WatermarkContent? text,
  }) => WatermarkPainter(
    content: text ?? content,
    config: config,
    imageSize: size,
  );

  test('every template and position stays inside the image', () {
    final frame = Offset.zero & image;
    for (final template in WatermarkTemplate.values) {
      for (final position in WatermarkPosition.values) {
        for (final textSize in WatermarkTextSize.values) {
          final painter = painterFor(
            WatermarkConfig(
              template: template,
              position: position,
              textSize: textSize,
            ),
          );
          expect(painter.bounds.isEmpty, isFalse);
          expect(
            frame.intersect(painter.bounds),
            painter.bounds,
            reason: '$template $position $textSize',
          );
          painter.dispose();
        }
      }
    }
  });

  test('positions follow the setting along the bottom edge', () {
    final left = painterFor(const WatermarkConfig());
    final center = painterFor(
      const WatermarkConfig(position: WatermarkPosition.bottomCenter),
    );
    final right = painterFor(
      const WatermarkConfig(position: WatermarkPosition.bottomRight),
    );

    expect(left.bounds.left, closeTo(image.width - right.bounds.right, 0.01));
    expect(center.bounds.center.dx, closeTo(image.width / 2, 0.01));
    expect(left.bounds.bottom, closeTo(right.bounds.bottom, 0.01));
    expect(left.bounds.bottom, lessThan(image.height));
  });

  test('scales with resolution so text stays proportionate', () {
    final small = painterFor(const WatermarkConfig());
    final large = painterFor(
      const WatermarkConfig(),
      size: Size(image.width * 3, image.height * 3),
    );
    expect(large.bounds.width / small.bounds.width, closeTo(3, 0.15));
  });

  test('templates produce visibly different layouts', () {
    final sizes = {
      for (final t in WatermarkTemplate.values)
        t: painterFor(WatermarkConfig(template: t)).bounds.size,
    };
    expect(sizes.values.toSet(), hasLength(WatermarkTemplate.values.length));
    expect(
      sizes[WatermarkTemplate.minimal]!.height,
      lessThan(sizes[WatermarkTemplate.professional]!.height),
    );
  });

  test('empty content draws nothing', () {
    final empty = WatermarkContent.from(
      fixtureMetadata(),
      const WatermarkConfig(
        showDate: false,
        showTime: false,
        showCoordinates: false,
        showAccuracy: false,
        showAddress: false,
      ),
    );
    expect(
      painterFor(const WatermarkConfig(), text: empty).bounds.isEmpty,
      isTrue,
    );
  });

  testWidgets('rasterizes only the watermark area', (tester) async {
    final painter = painterFor(const WatermarkConfig());
    final overlay = await tester.runAsync(() => rasterizeWatermark(painter));

    expect(overlay, isNotNull);
    expect(overlay!.width, closeTo(painter.bounds.width, 2));
    expect(overlay.height, closeTo(painter.bounds.height, 2));
    expect(overlay.rgba.lengthInBytes, overlay.width * overlay.height * 4);
    final opaque = [
      for (var i = 3; i < overlay.rgba.length; i += 4) overlay.rgba[i],
    ].where((a) => a > 0).length;
    expect(opaque, greaterThan(overlay.width * overlay.height ~/ 2));
    painter.dispose();
  });
}
