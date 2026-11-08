import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/features/camera/models/capture_mode.dart';

/// Switches between photo and video. Shows the mode it switches to.
class CaptureModeSwitch extends StatelessWidget {
  const CaptureModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
    this.size = 52,
  });

  final CaptureMode mode;
  final ValueChanged<CaptureMode>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final next = mode.isVideo ? CaptureMode.photo : CaptureMode.video;
    final label = next.isVideo ? 'Video'.tr : 'Photo'.tr;
    return Tooltip(
      message: next.isVideo ? 'Switch to video'.tr : 'Switch to photo'.tr,
      child: Semantics(
        button: true,
        enabled: onChanged != null,
        label: next.isVideo ? 'Switch to video'.tr : 'Switch to photo'.tr,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onChanged == null ? null : () => onChanged!(next),
          radius: size / 2 + 8,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: onChanged == null ? 0.4 : 1,
            child: SizedBox(
              width: size,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: size * 0.8,
                    height: size * 0.8,
                    decoration: const BoxDecoration(
                      color: AppColors.viewfinderSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      next.isVideo
                          ? Icons.videocam_outlined
                          : Icons.photo_camera_outlined,
                      color: AppColors.onViewfinder,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.onViewfinder,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
