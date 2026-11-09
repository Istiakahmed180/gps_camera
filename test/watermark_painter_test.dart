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
    // Card templates are full width, so a sized one is used.
    const base = WatermarkConfig(template: WatermarkTemplate.classic);
    final left = painterFor(base);
    final center = painterFor(
      base.copyWith(position: WatermarkPosition.bottomCenter),
    );
    final right = painterFor(
      base.copyWith(position: WatermarkPosition.bottomRight),
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
    // Without a map, every card template is the same full-width banner.
    final cards = WatermarkTemplate.values.where((t) => t.isCard).toList();
    for (final card in cards) {
      expect(sizes[card], sizes[WatermarkTemplate.banner], reason: card.name);
    }
    expect(
      sizes.values.toSet(),
      hasLength(WatermarkTemplate.values.length - cards.length + 1),
    );
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
  test('right-to-left languages mirror the layout', () async {
    final recorder = PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 8, 8),
      Paint()..color = const Color(0xFF00FF00),
    );
    final map = await recorder.endRecording().toImage(8, 8);
    WatermarkPainter make({required bool rtl}) => WatermarkPainter(
      content: content,
      config: const WatermarkConfig(template: WatermarkTemplate.map),
      imageSize: image,
      mapImage: map,
      rtl: rtl,
    );
    final ltr = make(rtl: false);
    final rtl = make(rtl: true);
    expect(rtl.bounds.left, closeTo(ltr.bounds.left, 0.01));
    expect(rtl.bounds.width, closeTo(ltr.bounds.width, 0.01));
    expect(ltr.mapRect!.center.dx, lessThan(ltr.bounds.center.dx));
    expect(rtl.mapRect!.center.dx, greaterThan(rtl.bounds.center.dx));
    expect(
      rtl.mapRect!.right - rtl.bounds.left,
      closeTo(ltr.bounds.right - ltr.mapRect!.left, 0.01),
    );
    // Draws without errors.
    final out = PictureRecorder();
    rtl.paint(Canvas(out));
    out.endRecording().dispose();
    ltr.dispose();
    rtl.dispose();
    map.dispose();
  });
}
