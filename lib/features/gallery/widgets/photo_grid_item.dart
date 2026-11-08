import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/utils/script.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/shared/widgets/media_thumbnail.dart';

class PhotoGridItem extends StatelessWidget {
  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.decodeWidth,
    required this.hasOriginal,
    required this.onTap,
    this.onLongPress,
  });

  final VoidCallback? onLongPress;

  final GalleryPhoto photo;

  /// Pixel width to decode the thumbnail at, never the full image.
  final int decodeWidth;

  /// For watermarked copies: whether their original still exists.
  final bool hasOriginal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metadata = photo.metadata;
    final (date, time) = metadata == null
        ? ('No capture data'.tr, null)
        : PhotoInfoFormatter.captureParts(metadata);
    final caption = time == null ? date : '$date · $time';
    final label = switch ((photo.isOriginal, photo.isVideo)) {
      (true, false) => 'Original photo, @caption',
      (false, false) => 'Watermarked photo, @caption',
      (true, true) => 'Original video, @caption',
      (false, true) => 'Stamped video, @caption',
    }.trParams({'caption': caption});

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: context.colors.surfaceContainer,
        borderRadius: AppRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaThumbnail(
                photo.path,
                key: ValueKey('${photo.path}:${photo.modifiedAt}'),
                cacheWidth: decodeWidth,
                duration: photo.videoDuration,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xB3000000)],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.xs + AppSpacing.xxs,
                top: AppSpacing.xs + AppSpacing.xxs,
                child: _KindBadge(isOriginal: photo.isOriginal),
              ),
              if (photo.issue != null || (photo.isWatermarked && !hasOriginal))
                Positioned(
                  right: AppSpacing.xs + AppSpacing.xxs,
                  top: AppSpacing.xs + AppSpacing.xxs,
                  child: Icon(
                    photo.issue != null
                        ? Icons.warning_amber_rounded
                        : Icons.link_off_rounded,
                    size: AppSizes.iconSm,
                    color: AppColors.accent,
                  ),
                ),
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: AppSpacing.xs + AppSpacing.xxs,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (time != null)
                      Text(
                        time,
                        maxLines: 1,
                        style: context.text.labelMedium?.copyWith(
                          color: AppColors.onViewfinder,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: AppColors.onViewfinderMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.isOriginal});

  final bool isOriginal;

  @override
  Widget build(BuildContext context) {
    final badge = isOriginal ? 'ORIGINAL'.tr : 'WATERMARKED'.tr;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOriginal ? const Color(0x99000000) : AppColors.accent,
        borderRadius: AppRadius.smAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs + AppSpacing.xxs,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          badge,
          style: context.text.labelSmall?.copyWith(
            fontSize: 9,
            letterSpacing: isLatinText(badge) ? 0.8 : 0,
            fontWeight: FontWeight.w700,
            color: isOriginal ? AppColors.onViewfinder : AppColors.onAccent,
          ),
        ),
      ),
    );
  }
}
