import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/core/utils/script.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/app/theme/app_text_styles.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/location/models/gps_accuracy_level.dart';
import 'package:gps_camera/features/location/models/location_fix.dart';
import 'package:gps_camera/features/location/models/location_status.dart';
import 'package:gps_camera/features/location/utils/location_formatter.dart';

/// Compact GPS readout for the camera screen.
class GpsStatusPanel extends StatelessWidget {
  const GpsStatusPanel({
    super.key,
    required this.status,
    required this.fix,
    required this.isStale,
    required this.onRequestPermission,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
    required this.onRetry,
  });

  final LocationStatus status;
  final LocationFix? fix;
  final bool isStale;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenLocationSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final view = _describe();

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'GPS: @title. @detail'.trParams({
        'title': view.title.tr,
        'detail': view.detail?.tr ?? '',
      }),
      excludeSemantics: view.action == null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.viewfinderSurface,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            _Indicator(color: view.color, busy: view.busy),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _Texts(view: view)),
            if (view.trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Text(
                  keepLtrRuns(
                    view.trailing!,
                    rtl: Directionality.of(context) == TextDirection.rtl,
                  ),
                  style: context.text.titleSmall
                      ?.merge(AppTextStyles.tabularFigures)
                      .copyWith(color: view.color),
                ),
              ),
            ],
            if (view.action != null) view.action!,
          ],
        ),
      ),
    );
  }

  _PanelView _describe() {
    final current = fix;

    if (current != null &&
        (status == LocationStatus.ready ||
            status == LocationStatus.acquiring)) {
      if (isStale && status == LocationStatus.acquiring) {
        return _PanelView(
          title: 'Updating GPS · last known location',
          detail: _coordinates(current),
          color: AppColors.onViewfinderMuted,
          trailing: LocationFormatter.accuracy(current.accuracy),
          busy: true,
        );
      }
      if (isStale) {
        return _PanelView(
          title: 'GPS signal lost · last known location',
          detail: _coordinates(current),
          color: AppColors.onViewfinderMuted,
          trailing: LocationFormatter.accuracy(current.accuracy),
        );
      }
      final level = GpsAccuracyLevel.fromMeters(current.accuracy);
      return _PanelView(
        title: switch (level) {
          GpsAccuracyLevel.good => 'GPS ready · Good accuracy',
          GpsAccuracyLevel.moderate => 'GPS ready · Moderate accuracy',
          GpsAccuracyLevel.poor => 'Poor GPS accuracy',
        },
        detail: _coordinates(current),
        color: _levelColor(level),
        trailing: LocationFormatter.accuracy(current.accuracy),
      );
    }

    return switch (status) {
      LocationStatus.idle ||
      LocationStatus.acquiring ||
      LocationStatus.ready => const _PanelView(
        title: 'Acquiring GPS…',
        detail: 'Waiting for the first location fix',
        color: AppColors.onViewfinderMuted,
        busy: true,
      ),
      LocationStatus.permissionDenied => _PanelView(
        title: 'Location permission needed',
        detail: 'Photos are saved without location',
        color: AppColors.errorDark,
        action: _ActionButton('Allow', onRequestPermission),
      ),
      LocationStatus.permissionBlocked => _PanelView(
        title: 'Location access is turned off',
        detail: 'Enable it in app settings to tag photos',
        color: AppColors.errorDark,
        action: _ActionButton('Settings', onOpenAppSettings),
      ),
      LocationStatus.serviceDisabled => _PanelView(
        title: 'Location services are off',
        detail: 'Turn on device location to tag photos',
        color: AppColors.errorDark,
        action: _ActionButton('Turn on', onOpenLocationSettings),
      ),
      LocationStatus.unavailable => _PanelView(
        title: 'GPS unavailable',
        detail: 'No location fix yet. Try moving to open sky.',
        color: AppColors.warning,
        action: _ActionButton('Retry', onRetry),
      ),
    };
  }

  static String _coordinates(LocationFix fix) {
    final parts = [
      '${LocationFormatter.latitude(fix.latitude)}  '
          '${LocationFormatter.longitude(fix.longitude)}',
      if (fix.altitude != null)
        LocationFormatter.altitude(fix.altitude!, fix.altitudeReference),
    ];
    return parts.join('  ·  ');
  }

  static Color _levelColor(GpsAccuracyLevel level) => switch (level) {
    GpsAccuracyLevel.good => AppColors.success,
    GpsAccuracyLevel.moderate => AppColors.warning,
    GpsAccuracyLevel.poor => AppColors.errorDark,
  };
}

class _PanelView {
  const _PanelView({
    required this.title,
    required this.color,
    this.detail,
    this.trailing,
    this.action,
    this.busy = false,
  });

  final String title;
  final String? detail;
  final Color color;
  final String? trailing;
  final Widget? action;
  final bool busy;
}

class _Texts extends StatelessWidget {
  const _Texts({required this.view});

  final _PanelView view;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          view.title.tr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelLarge?.copyWith(
            color: AppColors.onViewfinder,
          ),
        ),
        if (view.detail != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              keepLtrRuns(
                view.detail!.tr,
                rtl: Directionality.of(context) == TextDirection.rtl,
              ),
              maxLines: 1,
              style: context.text.bodySmall
                  ?.merge(AppTextStyles.tabularFigures)
                  .copyWith(color: AppColors.onViewfinderMuted),
            ),
          ),
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.color, required this.busy});

  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSizes.iconMd,
      child: Center(
        child: busy
            ? SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(
                Icons.gps_fixed_rounded,
                size: AppSizes.iconSm,
                color: color,
              ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        minimumSize: const Size(48, 40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      child: Text(label.tr),
    );
  }
}
