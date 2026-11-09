import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/count_text.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/widgets/project_cover.dart';
import 'package:gps_camera/features/watermark/utils/capture_time_formatter.dart';
import 'package:gps_camera/shared/widgets/media_thumbnail.dart';

/// Brand gradient shared by the dashboard's camera card.
const LinearGradient _brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1488BA), Color(0xFF07506F)],
);

/// The big camera card: what the app is for, one tap away, with where the
/// last capture was taken.
class CaptureCard extends StatelessWidget {
  const CaptureCard({super.key, required this.onTap, this.last});

  final VoidCallback onTap;

  /// The most recent capture, if any.
  final GalleryPhoto? last;

  @override
  Widget build(BuildContext context) {
    final last = _last();

    return Material(
      borderRadius: AppRadius.xlAll,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(gradient: _brandGradient),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Capture proof'.tr,
                            style: context.text.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Photos and videos stamped with location, date '
                                    'and time.'
                                .tr,
                            style: context.text.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        color: AppColors.onAccent,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          last == null
                              ? Icons.my_location_rounded
                              : Icons.place_rounded,
                          size: AppSizes.iconSm,
                          color: Colors.white,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: last == null
                              ? Text(
                                  'Tap to open the camera'.tr,
                                  style: context.text.labelLarge?.copyWith(
                                    color: Colors.white,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Last capture · @date'.trParams({
                                        'date': last.$2,
                                      }),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.text.labelSmall?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.75,
                                        ),
                                      ),
                                    ),
                                    if (last.$1 != null)
                                      Text(
                                        last.$1!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.text.labelLarge
                                            ?.copyWith(color: Colors.white),
                                      ),
                                  ],
                                ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: AppSizes.iconSm,
                          color: Colors.white,
                        ),
                      ],
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

  /// Where (if known) and when the last capture was taken:
  /// (`Tongi, Dhaka Division, Bangladesh`, `07 Nov 2026`).
  (String?, String)? _last() {
    final metadata = last?.metadata;
    if (metadata == null) return null;
    final place =
        metadata.place?.title ?? metadata.location.fix?.address?.trim();
    final date = CaptureTimeFormatter.date(
      CaptureTimeFormatter.wallClock(
        metadata.capturedAt,
        metadata.timeZoneOffset,
      ),
    );
    return (place == null || place.isEmpty ? null : place, date);
  }
}

/// A figure on the dashboard, e.g. 42 photos; tapping opens its tab.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final int value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: '$value $label',
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '$value',
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
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

/// A section title with an optional action on the right, e.g. "See all".
class DashboardSection extends StatelessWidget {
  const DashboardSection({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

/// The newest captures in a sideways strip.
class RecentCaptures extends StatelessWidget {
  const RecentCaptures({
    super.key,
    required this.photos,
    required this.onOpen,
    required this.onCamera,
  });

  final List<GalleryPhoto> photos;
  final ValueChanged<GalleryPhoto> onOpen;
  final VoidCallback onCamera;

  static const double _side = 112;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return _EmptyCard(
        icon: Icons.photo_camera_outlined,
        title: 'No captures yet'.tr,
        message: 'Your photos and videos will appear here.'.tr,
        action: 'Open camera'.tr,
        onAction: onCamera,
      );
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      height: _side,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final photo = photos[index];
          return Semantics(
            button: true,
            label: photo.isVideo ? 'Video'.tr : 'Photo'.tr,
            child: GestureDetector(
              onTap: () => onOpen(photo),
              child: ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: SizedBox.square(
                  dimension: _side,
                  child: MediaThumbnail(
                    photo.path,
                    cacheWidth: (_side * dpr).round(),
                    duration: photo.videoDuration,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The most recently changed active projects.
class RecentProjects extends StatelessWidget {
  const RecentProjects({
    super.key,
    required this.projects,
    required this.coverPath,
    required this.onOpen,
    required this.onCreate,
  });

  final List<ProjectSummary> projects;
  final String? Function(ProjectSummary) coverPath;
  final ValueChanged<ProjectSummary> onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return _EmptyCard(
        icon: Icons.folder_outlined,
        title: 'No projects yet'.tr,
        message: 'Create a project to group photos by site, client or job.'.tr,
        action: 'New project'.tr,
        onAction: onCreate,
      );
    }
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, summary) in projects.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 76),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              leading: ClipRRect(
                borderRadius: AppRadius.smAll,
                child: SizedBox.square(
                  dimension: 48,
                  child: ProjectCover(path: coverPath(summary), iconSize: 22),
                ),
              ),
              title: Text(
                summary.project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall,
              ),
              subtitle: Text(
                '@n photo'.trCount('@n photos', summary.photoCount, {
                  'n': '${summary.photoCount}',
                }),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onOpen(summary),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(icon, color: colors.onPrimaryContainer),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    message,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
