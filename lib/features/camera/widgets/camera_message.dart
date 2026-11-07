import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';

/// Status panel shown inside the viewfinder for loading, permission and
/// error states.
class CameraMessage extends StatelessWidget {
  const CameraMessage({
    super.key,
    required this.title,
    this.icon,
    this.message,
    this.action,
    this.isLoading = false,
  });

  final String title;
  final IconData? icon;
  final String? message;
  final Widget? action;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox.square(
                  dimension: AppSizes.iconLg,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.onViewfinder,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 48, color: AppColors.onViewfinderMuted),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.titleMedium?.copyWith(
                  color: AppColors.onViewfinder,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: AppColors.onViewfinderMuted,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
