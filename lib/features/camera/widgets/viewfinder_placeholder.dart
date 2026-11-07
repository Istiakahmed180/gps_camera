import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';

class ViewfinderPlaceholder extends StatelessWidget {
  const ViewfinderPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.viewfinderSurface,
        borderRadius: AppRadius.lgAll,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_outlined,
              size: 48,
              color: AppColors.onViewfinderMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Camera preview',
              style: context.text.titleMedium?.copyWith(
                color: AppColors.onViewfinder,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Live capture is not available yet.',
              style: context.text.bodySmall?.copyWith(
                color: AppColors.onViewfinderMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
