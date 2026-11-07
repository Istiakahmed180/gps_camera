import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_colors.dart';

/// Round translucent control used on top of the viewfinder.
class CameraIconButton extends StatelessWidget {
  const CameraIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  /// Highlights a toggle that is on.
  final bool active;

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        foregroundColor: active ? AppColors.accent : AppColors.onViewfinder,
        backgroundColor: AppColors.viewfinderSurface,
        disabledForegroundColor: AppColors.onViewfinderMuted.withValues(
          alpha: 0.5,
        ),
        disabledBackgroundColor: AppColors.viewfinderSurface.withValues(
          alpha: 0.5,
        ),
        fixedSize: const Size.square(44),
      ),
    );
  }
}
