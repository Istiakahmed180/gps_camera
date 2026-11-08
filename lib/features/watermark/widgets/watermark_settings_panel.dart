import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/watermark/models/watermark_config.dart';
import 'package:gps_camera/shared/widgets/section_header.dart';

/// Visibility, size, opacity and position controls.
class WatermarkSettingsPanel extends StatelessWidget {
  const WatermarkSettingsPanel({
    super.key,
    required this.config,
    required this.hasAddress,
    required this.onChanged,
    this.hasNote = false,
    this.hasDirection = false,
  });

  /// Whether this photo recorded a compass direction.
  final bool hasDirection;

  final WatermarkConfig config;
  final bool hasAddress;

  /// Whether this photo has a note to show.
  final bool hasNote;
  final ValueChanged<WatermarkConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Details'.tr),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _toggle(
              'Date'.tr,
              config.showDate,
              (v) => config.copyWith(showDate: v),
            ),
            _toggle(
              'Time'.tr,
              config.showTime,
              (v) => config.copyWith(showTime: v),
            ),
            _toggle(
              'Coordinates'.tr,
              config.showCoordinates,
              (v) => config.copyWith(showCoordinates: v),
            ),
            _toggle(
              'Accuracy'.tr,
              config.showAccuracy,
              (v) => config.copyWith(showAccuracy: v),
            ),
            Tooltip(
              message: hasAddress
                  ? ''
                  : 'No address is recorded for this photo'.tr,
              child: _toggle(
                'Address'.tr,
                config.showAddress && hasAddress,
                (v) => config.copyWith(showAddress: v),
                enabled: hasAddress,
              ),
            ),
            Tooltip(
              message: hasDirection
                  ? ''
                  : 'No compass direction was recorded for this photo'.tr,
              child: _toggle(
                'Direction'.tr,
                config.showDirection && hasDirection,
                (v) => config.copyWith(showDirection: v),
                enabled: hasDirection,
              ),
            ),
            Tooltip(
              message: hasNote ? '' : 'This photo has no note'.tr,
              child: _toggle(
                'Note'.tr,
                config.showNote && hasNote,
                (v) => config.copyWith(showNote: v),
                enabled: hasNote,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader('Position'.tr),
        SegmentedButton<WatermarkPosition>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: WatermarkPosition.bottomLeft,
              label: Text('Left'.tr),
              icon: const Icon(Icons.align_horizontal_left_rounded),
            ),
            ButtonSegment(
              value: WatermarkPosition.bottomCenter,
              label: Text('Center'.tr),
              icon: const Icon(Icons.align_horizontal_center_rounded),
            ),
            ButtonSegment(
              value: WatermarkPosition.bottomRight,
              label: Text('Right'.tr),
              icon: const Icon(Icons.align_horizontal_right_rounded),
            ),
          ],
          selected: {config.position},
          onSelectionChanged: (s) =>
              onChanged(config.copyWith(position: s.first)),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader('Text size'.tr),
        SegmentedButton<WatermarkTextSize>(
          showSelectedIcon: false,
          segments: [
            for (final size in WatermarkTextSize.values)
              ButtonSegment(
                value: size,
                label: Text(switch (size) {
                  WatermarkTextSize.small => 'Small'.tr,
                  WatermarkTextSize.medium => 'Medium'.tr,
                  WatermarkTextSize.large => 'Large'.tr,
                }),
              ),
          ],
          selected: {config.textSize},
          onSelectionChanged: (s) =>
              onChanged(config.copyWith(textSize: s.first)),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(child: SectionHeader('Opacity'.tr)),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '${(config.opacity * 100).round()}%',
                style: context.text.labelLarge,
              ),
            ),
          ],
        ),
        Slider(
          value: config.opacity,
          min: WatermarkConfig.minOpacity,
          divisions: 12,
          label: '${(config.opacity * 100).round()}%',
          onChanged: (v) => onChanged(config.copyWith(opacity: v)),
        ),
      ],
    );
  }

  Widget _toggle(
    String label,
    bool selected,
    WatermarkConfig Function(bool) update, {
    bool enabled = true,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (v) => onChanged(update(v)) : null,
    );
  }
}
