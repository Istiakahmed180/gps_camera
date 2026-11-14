import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/models/watermark_template.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';

/// Every template, one under the other, each drawn full width with the
/// real details so the user picks by how it will actually look.
class WatermarkTemplateList extends StatelessWidget {
  const WatermarkTemplateList({
    super.key,
    required this.selected,
    required this.content,
    required this.config,
    required this.onSelected,
    this.mapImage,
    this.logoImage,
  });

  final WatermarkTemplate selected;
  final WatermarkContent content;
  final WatermarkConfig config;
  final ValueChanged<WatermarkTemplate> onSelected;
  final ui.Image? mapImage;
  final ui.Image? logoImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final template in WatermarkTemplate.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: WatermarkTemplateTile(
              template: template,
              isSelected: template == selected,
              content: content,
              config: config.copyWith(template: template, opacity: 1),
              mapImage: mapImage,
              logoImage: logoImage,
              onTap: () => onSelected(template),
            ),
          ),
      ],
    );
  }
}

/// One template's stamp on a dark strip, with its name underneath.
class WatermarkTemplateTile extends StatelessWidget {
  const WatermarkTemplateTile({
    super.key,
    required this.template,
    required this.isSelected,
    required this.content,
    required this.config,
    required this.onTap,
    this.mapImage,
    this.logoImage,
  });

  final WatermarkTemplate template;
  final bool isSelected;
  final WatermarkContent content;
  final WatermarkConfig config;
  final VoidCallback onTap;
  final ui.Image? mapImage;
  final ui.Image? logoImage;

  /// The stamp is laid out on a portrait photo of this size.
  static const Size _photo = Size(1080, 1920);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stamp = WatermarkPainter(
      content: content,
      config: config,
      imageSize: _photo,
      mapImage: mapImage,
      reserveMapSlot: true,
      logoImage: logoImage,
    );
    final bounds = stamp.bounds;
    stamp.dispose();

    return Semantics(
      button: true,
      selected: isSelected,
      label: '@name template. @description'.trParams({
        'name': template.label.tr,
        'description': template.description.tr,
      }),
      excludeSemantics: true,
      // The InkWell's own tap action is excluded with it.
      onTap: onTap,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(
            color: isSelected ? colors.primary : colors.outlineVariant,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!bounds.isEmpty)
                ColoredBox(
                  color: const Color(0xFF55616C),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: AspectRatio(
                      // Card templates fill the width; the others keep their
                      // size relative to a card so they look as small as
                      // they are.
                      aspectRatio: _photo.width / (bounds.height + 24),
                      child: CustomPaint(
                        painter: _StampPainter(
                          content: content,
                          config: config,
                          mapImage: mapImage,
                          logoImage: logoImage,
                          photo: _photo,
                          bounds: bounds,
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        template.label.tr,
                        style: context.text.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: AppSizes.iconSm,
                        color: colors.primary,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the stamp's area of a [photo]-sized image, scaled to the width.
class _StampPainter extends CustomPainter {
  const _StampPainter({
    required this.content,
    required this.config,
    required this.photo,
    required this.bounds,
    this.mapImage,
    this.logoImage,
  });

  final WatermarkContent content;
  final WatermarkConfig config;
  final Size photo;
  final Rect bounds;
  final ui.Image? mapImage;
  final ui.Image? logoImage;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / photo.width;
    final painter = WatermarkPainter(
      content: content,
      config: config,
      imageSize: photo,
      mapImage: mapImage,
      reserveMapSlot: true,
      logoImage: logoImage,
    );
    canvas
      ..save()
      ..scale(scale)
      ..translate(0, -bounds.top + 12);
    painter
      ..paint(canvas)
      ..dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StampPainter old) =>
      old.config != config ||
      old.bounds != bounds ||
      !identical(old.content, content) ||
      !identical(old.mapImage, mapImage) ||
      !identical(old.logoImage, logoImage);
}
