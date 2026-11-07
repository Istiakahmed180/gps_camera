import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/features/watermark/models/watermark_content.dart';
import 'package:gps_camera/features/watermark/models/watermark_template.dart';
import 'package:gps_camera/features/watermark/services/watermark_painter.dart';

/// Template cards, each showing this photo's details in that template.
class WatermarkStyleSelector extends StatelessWidget {
  const WatermarkStyleSelector({
    super.key,
    required this.selected,
    required this.content,
    required this.config,
    required this.onSelected,
  });

  final WatermarkTemplate selected;
  final WatermarkContent content;
  final WatermarkConfig config;
  final ValueChanged<WatermarkTemplate> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, template) in WatermarkTemplate.values.indexed) ...[
          if (index > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _TemplateCard(
              template: template,
              isSelected: template == selected,
              content: content,
              config: config.copyWith(
                template: template,
                position: WatermarkPosition.bottomLeft,
                textSize: WatermarkTextSize.medium,
                opacity: 1,
              ),
              onTap: () => onSelected(template),
            ),
          ),
        ],
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.content,
    required this.config,
    required this.onTap,
  });

  final WatermarkTemplate template;
  final bool isSelected;
  final WatermarkContent content;
  final WatermarkConfig config;
  final VoidCallback onTap;

  static const double _aspectRatio = 1.45;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${template.label} template. ${template.description}',
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(
            color: isSelected ? colors.primary : colors.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: _aspectRatio,
                  child: ClipRRect(
                    borderRadius: AppRadius.smAll,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF6B7F8E), Color(0xFF3B4650)],
                        ),
                      ),
                      child: CustomPaint(
                        painter: _TemplateSamplePainter(
                          content: content,
                          config: config,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        template.label,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the template's watermark enlarged to fill the card, so templates
/// can be compared at a glance.
class _TemplateSamplePainter extends CustomPainter {
  const _TemplateSamplePainter({required this.content, required this.config});

  static const Size _canvas = Size(1000, 1000);

  final WatermarkContent content;
  final WatermarkConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = WatermarkPainter(
      content: content,
      config: config,
      imageSize: _canvas,
      reserveMapSlot: true,
    );
    final bounds = painter.bounds;
    if (!bounds.isEmpty) {
      final scale = math.min(
        size.width * 0.88 / bounds.width,
        size.height * 0.8 / bounds.height,
      );
      canvas
        ..save()
        ..translate(
          (size.width - bounds.width * scale) / 2,
          size.height - bounds.height * scale - size.height * 0.08,
        )
        ..scale(scale)
        ..translate(-bounds.left, -bounds.top);
      painter.paint(canvas);
      canvas.restore();
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_TemplateSamplePainter old) =>
      old.config != config || !identical(old.content, content);
}

/// Muted background colour reused by the editor's preview area.
const Color watermarkStageColor = AppColors.viewfinderSurface;
