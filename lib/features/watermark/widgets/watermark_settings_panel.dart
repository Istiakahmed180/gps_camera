import 'package:flutter/material.dart';
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
  });

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
        const SectionHeader('Details'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _toggle(
              'Date',
              config.showDate,
              (v) => config.copyWith(showDate: v),
            ),
            _toggle(
              'Time',
              config.showTime,
              (v) => config.copyWith(showTime: v),
            ),
            _toggle(
              'Coordinates',
              config.showCoordinates,
              (v) => config.copyWith(showCoordinates: v),
            ),
            _toggle(
              'Accuracy',
              config.showAccuracy,
              (v) => config.copyWith(showAccuracy: v),
            ),
            Tooltip(
              message: hasAddress
                  ? ''
                  : 'No address is recorded for this photo',
              child: _toggle(
                'Address',
                config.showAddress && hasAddress,
                (v) => config.copyWith(showAddress: v),
                enabled: hasAddress,
              ),
            ),
            Tooltip(
              message: hasNote ? '' : 'This photo has no note',
              child: _toggle(
                'Note',
                config.showNote && hasNote,
                (v) => config.copyWith(showNote: v),
                enabled: hasNote,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader('Position'),
        SegmentedButton<WatermarkPosition>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: WatermarkPosition.bottomLeft,
              label: Text('Left'),
              icon: Icon(Icons.align_horizontal_left_rounded),
            ),
            ButtonSegment(
              value: WatermarkPosition.bottomCenter,
              label: Text('Center'),
              icon: Icon(Icons.align_horizontal_center_rounded),
            ),
            ButtonSegment(
              value: WatermarkPosition.bottomRight,
              label: Text('Right'),
              icon: Icon(Icons.align_horizontal_right_rounded),
            ),
          ],
          selected: {config.position},
          onSelectionChanged: (s) =>
              onChanged(config.copyWith(position: s.first)),
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionHeader('Text size'),
        SegmentedButton<WatermarkTextSize>(
          showSelectedIcon: false,
          segments: [
            for (final size in WatermarkTextSize.values)
              ButtonSegment(
                value: size,
                label: Text(switch (size) {
                  WatermarkTextSize.small => 'Small',
                  WatermarkTextSize.medium => 'Medium',
                  WatermarkTextSize.large => 'Large',
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
            const Expanded(child: SectionHeader('Opacity')),
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
