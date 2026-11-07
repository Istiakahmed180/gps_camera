import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';

/// Preview of the most recent capture, confirming it was saved.
class LastPhotoThumbnail extends StatelessWidget {
  const LastPhotoThumbnail({super.key, required this.path});

  static const double size = 52;

  final String? path;

  @override
  Widget build(BuildContext context) {
    final current = path;

    return Container(
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
  }
}
