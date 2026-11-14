import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/count_text.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/backup/controllers/drive_backup_controller.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/home/controllers/current_place_controller.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/utils/location_formatter.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/widgets/project_cover.dart';
import 'package:gps_camera/shared/widgets/media_thumbnail.dart';
import 'package:gps_camera/shared/widgets/soft_surface.dart';
import 'package:gps_camera/app/theme/soft_theme.dart';

/// The big camera card: what the app is for, one tap away, with where the
/// phone is right now.
class CaptureCard extends StatelessWidget {
  const CaptureCard({super.key, required this.onTap, required this.here});

  final VoidCallback onTap;

  /// The phone's current location.
  final CurrentPlaceController here;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlAll,
        boxShadow: [
          BoxShadow(
            color: AppColors.glossTop.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        borderRadius: AppRadius.xlAll,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(gradient: SoftTheme.gloss),
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
                  _HereStrip(here: here),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The current location inside the camera card: the place name, its
/// address or coordinates, and how precise it is. Without location access
/// it says so, and a tap asks for it.
class _HereStrip extends StatelessWidget {
  const _HereStrip({required this.here});

  final CurrentPlaceController here;

  /// A fix older than this is labelled as the last known location.
  static const Duration _fresh = Duration(minutes: 2);

  @override
  Widget build(BuildContext context) {
    final small = context.text.labelSmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.78),
    );
    final big = context.text.labelLarge?.copyWith(color: Colors.white);

    return Obx(() {
      final status = here.status.value;
      final fix = here.fix.value;
      final place = here.place.value;
      final needsAction =
          status == CurrentPlaceStatus.noPermission ||
          status == CurrentPlaceStatus.blocked ||
          status == CurrentPlaceStatus.off;

      final (IconData icon, String top, String main) = switch (status) {
        CurrentPlaceStatus.found when fix != null => (
          Icons.my_location_rounded,
          _caption(fix),
          place?.title ??
              place?.addressLine ??
              '${LocationFormatter.latitude(fix.latitude)}, '
                  '${LocationFormatter.longitude(fix.longitude)}',
        ),
        CurrentPlaceStatus.noPermission => (
          Icons.location_off_outlined,
          'Location access needed'.tr,
          'Tap to allow location'.tr,
        ),
        CurrentPlaceStatus.blocked => (
          Icons.location_off_outlined,
          'Location access is off for Locaproof'.tr,
          'Tap to open settings'.tr,
        ),
        CurrentPlaceStatus.off => (
          Icons.location_disabled_rounded,
          'Phone location is off'.tr,
          'Tap to turn it on'.tr,
        ),
        CurrentPlaceStatus.unavailable => (
          Icons.gps_not_fixed_rounded,
          'Current location'.tr,
          'Location not found yet. Tap to try again.'.tr,
        ),
        _ => (
          Icons.gps_not_fixed_rounded,
          'Current location'.tr,
          'Finding your location…'.tr,
        ),
      };
      // The address line, when the title above is only the town.
      final detail = status == CurrentPlaceStatus.found
          ? place?.addressLine
          : null;

      return Material(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: AppRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Taps on the strip fix access or retry; the rest of the card
          // opens the camera.
          onTap: needsAction || status == CurrentPlaceStatus.unavailable
              ? () => here.fixAccess()
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (status == CurrentPlaceStatus.locating)
                  const SizedBox.square(
                    dimension: AppSizes.iconSm,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, size: AppSizes.iconSm, color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        top,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: small,
                      ),
                      Text(
                        main,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: big,
                      ),
                      if (detail != null && detail != main)
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: small,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  needsAction
                      ? Icons.chevron_right_rounded
                      : status == CurrentPlaceStatus.unavailable
                      ? Icons.refresh_rounded
                      : Icons.arrow_forward_rounded,
                  size: AppSizes.iconSm,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// `Current location · ±8 m`, or the last known location when old.
  static String _caption(LocationFix fix) {
    final accuracy = LocationFormatter.accuracy(fix.accuracy);
    final old = fix.ageAt(DateTime.now()) > _fresh;
    return old
        ? 'Last known location · @accuracy'.trParams({'accuracy': accuracy})
        : 'Current location · @accuracy'.trParams({'accuracy': accuracy});
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
      // The InkWell's own tap action is excluded with it.
      onTap: onTap,
      child: SoftSurface(
        radius: 18,
        depth: 4,
        onTap: onTap,
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
    return SoftSurface(
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
    return SoftSurface(
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

/// Shown on the dashboard while photos exist only on this phone: turns on
/// Google Drive backup, or says why backup stopped.
class BackupReminder extends StatelessWidget {
  const BackupReminder({
    super.key,
    required this.drive,
    required this.captureCount,
    required this.onOpenSettings,
  });

  final DriveBackupController drive;
  final int captureCount;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Read first: an Obx must always listen to something.
      final signedIn = drive.account.value != null;
      final problem = drive.problem.value;
      final busy = drive.isBusy;
      if (!drive.isConfigured || captureCount == 0) {
        return const SizedBox.shrink();
      }
      if (signedIn && (problem == null || busy)) {
        return const SizedBox.shrink();
      }
      final colors = context.colors;
      final warning = signedIn;
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: SoftSurface(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (warning ? colors.error : AppColors.accent).withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(
                  warning
                      ? Icons.cloud_off_rounded
                      : Icons.add_to_drive_rounded,
                  color: warning ? colors.error : AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warning
                          ? 'Backup stopped'.tr
                          : 'Your photos are only on this phone'.tr,
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      warning
                          ? problem!
                          : ('If the app is removed they are lost. Back them '
                                    'up to Google Drive.')
                                .tr,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: warning
                    ? onOpenSettings
                    : () => unawaited(drive.signIn()),
                child: Text(warning ? 'Fix'.tr : 'Turn on'.tr),
              ),
            ],
          ),
        ),
      );
    });
  }
}
