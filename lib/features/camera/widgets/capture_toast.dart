import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/camera/models/capture_feedback.dart';

class CaptureToast extends StatelessWidget {
  const CaptureToast({super.key, required this.feedback});

  final CaptureFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    final current = feedback;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: current == null
          ? const SizedBox.shrink()
          : Semantics(
              liveRegion: true,
              child: DecoratedBox(
                key: ValueKey(current),
                decoration: BoxDecoration(
                  color: AppColors.viewfinderBackground.withValues(alpha: 0.85),
                  borderRadius: AppRadius.xlAll,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        current.isError
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        size: AppSizes.iconSm,
                        color: current.isError
                            ? context.colors.error
                            : AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          current.message,
                          style: context.text.labelLarge?.copyWith(
                            color: AppColors.onViewfinder,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
