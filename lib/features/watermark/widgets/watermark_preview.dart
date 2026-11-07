import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/services/image_processor.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';

/// The photo with its watermark, laid out exactly as it will be saved.
class WatermarkPreview extends StatelessWidget {
  const WatermarkPreview({
    super.key,
    required this.image,
    required this.content,
    required this.config,
    this.mapImage,
  });

  final PreviewImage image;
  final WatermarkContent content;
  final WatermarkConfig config;
  final ui.Image? mapImage;

  @override
  Widget build(BuildContext context) {
    final size = Size(image.width.toDouble(), image.height.toDouble());

    return Center(
      child: AspectRatio(
        aspectRatio: size.width / size.height,
        child: ClipRRect(
          borderRadius: AppRadius.mdAll,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                image.bytes,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                semanticLabel: 'Photo preview',
              ),
              CustomPaint(
                painter: WatermarkCanvasPainter(
                  content: content,
                  config: config,
                  imageSize: size,
                  mapImage: mapImage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints a [WatermarkPainter] scaled from image pixels to the widget size.
class WatermarkCanvasPainter extends CustomPainter {
  const WatermarkCanvasPainter({
    required this.content,
    required this.config,
    required this.imageSize,
    this.mapImage,
    this.reserveMapSlot = false,
  });

  final WatermarkContent content;
  final WatermarkConfig config;
  final Size imageSize;
  final ui.Image? mapImage;
  final bool reserveMapSlot;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.isEmpty) return;
    final painter = WatermarkPainter(
      content: content,
      config: config,
      imageSize: imageSize,
      mapImage: mapImage,
      reserveMapSlot: reserveMapSlot,
    );
    canvas
      ..save()
      ..scale(size.width / imageSize.width, size.height / imageSize.height);
    painter
      ..paint(canvas)
      ..dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(WatermarkCanvasPainter old) =>
      old.config != config ||
      old.imageSize != imageSize ||
      old.mapImage != mapImage ||
      old.reserveMapSlot != reserveMapSlot ||
      !identical(old.content, content);
}
