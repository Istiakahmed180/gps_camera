import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';

/// Preview of the most recent capture. Tapping it opens the watermark
/// editor for that photo.
class LastPhotoThumbnail extends StatelessWidget {
  const LastPhotoThumbnail({super.key, required this.path, this.onTap});

  static const double size = 52;

  final String? path;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final current = path;

    final frame = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.viewfinderSurface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.onViewfinder, width: 1.5),
      ),
      child: current == null
          ? null
          : Image.file(
              File(current),
              key: ValueKey(current),
              fit: BoxFit.cover,
              cacheWidth: 160,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: AppColors.onViewfinderMuted,
              ),
            ),
    );

    if (current == null || onTap == null) return frame;

    return Tooltip(
      message: 'Add watermark',
      child: Semantics(
        button: true,
        label: 'Add watermark to last photo',
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              frame,
              Positioned(
                right: -AppSpacing.xs,
                bottom: -AppSpacing.xs,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 12,
                    color: AppColors.onAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
