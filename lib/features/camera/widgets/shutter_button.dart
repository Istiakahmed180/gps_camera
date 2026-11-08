import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';

class ShutterButton extends StatelessWidget {
  const ShutterButton({
    super.key,
    required this.onPressed,
    this.isCapturing = false,
    this.isCountingDown = false,
    this.isVideo = false,
    this.isRecording = false,
  });

  /// Video mode: a red record button.
  final bool isVideo;

  /// Recording: a red stop square.
  final bool isRecording;

  final VoidCallback? onPressed;
  final bool isCapturing;

  /// A timer is running; tapping cancels it.
  final bool isCountingDown;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isCapturing;
    final fill = isRecording || (isVideo && !isCapturing && !isCountingDown)
        ? AppColors.recording
        : isCapturing || isCountingDown
        ? AppColors.accent
        : AppColors.onViewfinder;
    final innerScale = isRecording ? 0.45 : (isCapturing ? 0.7 : 1.0);
    const ring = 4.0;
    const gap = AppSpacing.xs + AppSpacing.xxs;
    const innerSize = AppSizes.shutter - (ring + gap) * 2;

    return Semantics(
      button: true,
      enabled: enabled,
      label: isRecording
          ? 'Stop recording'.tr
          : isCapturing
          ? (isVideo ? 'Saving video'.tr : 'Capturing photo'.tr)
          : isCountingDown
          ? 'Cancel timer'.tr
          : isVideo
          ? 'Start recording'.tr
          : 'Capture photo'.tr,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled || isCapturing ? 1 : 0.4,
          child: Container(
            width: AppSizes.shutter,
            height: AppSizes.shutter,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.onViewfinder, width: ring),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: innerSize * innerScale,
              height: innerSize * innerScale,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(
                  isRecording ? 8 : innerSize,
                ),
              ),
              child: isCountingDown
                  ? const Icon(
                      Icons.close_rounded,
                      color: AppColors.onAccent,
                      size: 32,
                    )
                  : isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.onAccent,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
