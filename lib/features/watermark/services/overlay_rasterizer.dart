import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:gps_camera/features/watermark/services/image_processor.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';

typedef OverlayRasterizer = Future<OverlayBitmap?> Function(
  WatermarkPainter painter,
);

/// Renders only the watermark's area at full image resolution. Returns null
/// when there is nothing to draw.
Future<OverlayBitmap?> rasterizeWatermark(WatermarkPainter painter) async {
  final bounds = painter.bounds;
  if (bounds.isEmpty) return null;

  final left = math.max(0, bounds.left.floor());
  final top = math.max(0, bounds.top.floor());
  final right = math.min(painter.imageSize.width.floor(), bounds.right.ceil());
  final bottom = math.min(
    painter.imageSize.height.floor(),
    bounds.bottom.ceil(),
  );
  final width = right - left;
  final height = bottom - top;
  if (width <= 0 || height <= 0) return null;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..translate(-left.toDouble(), -top.toDouble());
  painter.paint(canvas);
  final picture = recorder.endRecording();

  ui.Image? image;
  try {
    image = await picture.toImage(width, height);
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) return null;
    return OverlayBitmap(
      left: left,
      top: top,
      width: width,
      height: height,
      rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image?.dispose();
    picture.dispose();
  }
}
