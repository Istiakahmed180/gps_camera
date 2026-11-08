import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/features/camera/models/capture_timer.dart';
import 'package:gps_camera/features/camera/widgets/camera_icon_button.dart';

/// Grid and timer toggles on the left, zoom presets on the right.
class CameraControlsBar extends StatelessWidget {
  const CameraControlsBar({
    super.key,
    required this.showGrid,
    required this.timer,
    required this.zoom,
    required this.zoomPresets,
    required this.enabled,
    required this.onToggleGrid,
    required this.onCycleTimer,
    required this.onZoom,
    this.hasNote = false,
    this.onNote,
  });

  /// A note will be added to new photos.
  final bool hasNote;
  final VoidCallback? onNote;

  final bool showGrid;
  final CaptureTimer timer;
  final double zoom;
  final List<double> zoomPresets;
  final bool enabled;
  final VoidCallback onToggleGrid;
  final VoidCallback onCycleTimer;
  final ValueChanged<double> onZoom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Toggle(
          icon: showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
          tooltip: showGrid ? 'Hide grid'.tr : 'Show grid'.tr,
          active: showGrid,
          onPressed: onToggleGrid,
        ),
        const SizedBox(width: AppSpacing.sm),
        _Toggle(
          icon: timer == CaptureTimer.off
              ? Icons.timer_off_outlined
              : Icons.timer_outlined,
          tooltip: 'Timer: @value'.trParams({'value': timer.label.tr}),
          active: timer != CaptureTimer.off,
          badge: timer == CaptureTimer.off ? null : '${timer.seconds}',
          onPressed: enabled ? onCycleTimer : null,
        ),
        if (onNote != null) ...[
          const SizedBox(width: AppSpacing.sm),
          _Toggle(
            icon: hasNote
                ? Icons.sticky_note_2_rounded
                : Icons.sticky_note_2_outlined,
            tooltip: hasNote ? 'Edit note for new photos'.tr : 'Add a note'.tr,
            active: hasNote,
            onPressed: onNote,
          ),
        ],
        const Spacer(),
        if (zoomPresets.length > 1)
          _ZoomPresets(
            zoom: zoom,
            presets: zoomPresets,
            onZoom: enabled ? onZoom : null,
          ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final String? badge;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final button = CameraIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      active: active,
    );
    if (badge == null) return button;
    return Badge(
      label: Text(badge!),
      backgroundColor: AppColors.accent,
      textColor: AppColors.onAccent,
      offset: const Offset(-2, 2),
      child: button,
    );
  }
}

class _ZoomPresets extends StatelessWidget {
  const _ZoomPresets({
    required this.zoom,
    required this.presets,
    required this.onZoom,
  });

  final double zoom;
  final List<double> presets;
  final ValueChanged<double>? onZoom;

  /// The preset whose range the current zoom falls in.
  int get _selected {
    var index = 0;
    for (var i = 0; i < presets.length; i++) {
      if (zoom >= presets[i] - 0.05) index = i;
    }
    return index;
  }

  static String format(double z) {
    final rounded = (z * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.toInt()}×'
        : '${rounded.toStringAsFixed(1)}×';
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.viewfinderSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < presets.length; i++)
              _ZoomChip(
                // The active chip shows the exact zoom, e.g. 1.7×.
                label: i == selected ? format(zoom) : format(presets[i]),
                selected: i == selected,
                onTap: onZoom == null ? null : () => onZoom!(presets[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoomChip extends StatelessWidget {
  const _ZoomChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Zoom @value'.trParams({'value': label}),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? AppColors.accent.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.accent : AppColors.onViewfinder,
              fontSize: selected ? 13 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
