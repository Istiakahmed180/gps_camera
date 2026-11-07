import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';

/// Primary entry point to the camera. Intentionally dark in both themes
/// so it reads as a viewfinder.
class CaptureHeroCard extends StatelessWidget {
  const CaptureHeroCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: AppColors.viewfinderBackground,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlAll,
        side: isDark
            ? BorderSide(color: context.colors.outlineVariant)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  color: AppColors.onAccent,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open camera',
                      style: context.text.titleLarge?.copyWith(
                        color: AppColors.onViewfinder,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Capture photos stamped with location, date and time.',
                      style: context.text.bodyMedium?.copyWith(
                        color: AppColors.onViewfinderMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.onViewfinderMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
