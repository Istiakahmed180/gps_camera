import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';

class ShutterButton extends StatelessWidget {
  const ShutterButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Capture photo',
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: AppSizes.shutter,
            height: AppSizes.shutter,
            padding: const EdgeInsets.all(AppSpacing.xs + AppSpacing.xxs),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.onViewfinder, width: 4),
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.onViewfinder,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
