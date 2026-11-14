import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/count_text.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/backup/controllers/drive_backup_controller.dart';
import 'package:gps_camera/features/watermark/utils/capture_time_formatter.dart';

/// Google Drive backup in Settings: sign in, status, automatic backup
/// switches, back up now, restore, sign out.
class DriveBackupCard extends StatelessWidget {
  const DriveBackupCard({super.key, required this.drive});

  final DriveBackupController drive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Obx(() {
      final email = drive.account.value;
      final busy = drive.isBusy;
      final problem = drive.problem.value;

      if (!drive.isConfigured) {
        return ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text('Google Drive backup'.tr),
          subtitle: Text(
            'Google Drive backup is not set up in this version of the app.'.tr,
          ),
        );
      }

      if (email == null) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.add_to_drive_rounded, color: colors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Google Drive backup'.tr,
                      style: context.text.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                ('Photos, videos, projects and reports are copied to your '
                        'Google Drive by themselves, so they are safe if the '
                        'app is removed or the phone is lost.')
                    .tr,
                style: context.text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (problem != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  problem,
                  style: context.text.bodySmall?.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: busy ? null : () => unawaited(drive.signIn()),
                icon: const Icon(Icons.login_rounded),
                label: Text('Sign in with Google'.tr),
              ),
            ],
          ),
        );
      }

      final progress = drive.progress.value;
      final status = switch (drive.activity.value) {
        DriveActivity.backingUp =>
          progress == null
              ? 'Backing up…'.tr
              : 'Backing up… @done of @total'.trParams({
                  'done': '${progress.$1}',
                  'total': '${progress.$2}',
                }),
        DriveActivity.restoring =>
          progress == null
              ? 'Restoring…'.tr
              : 'Restoring… @done of @total'.trParams({
                  'done': '${progress.$1}',
                  'total': '${progress.$2}',
                }),
        DriveActivity.idle when drive.waitingForWifi.value =>
          'Waiting for Wi-Fi to back up'.tr,
        DriveActivity.idle => _lastBackupText(drive.lastBackup.value),
      };

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(Icons.add_to_drive_rounded, color: colors.primary),
            title: Text('Google Drive backup'.tr),
            subtitle: Text(email),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(status, style: context.text.bodyMedium),
                if (busy) ...[
                  const SizedBox(height: AppSpacing.sm),
                  LinearProgressIndicator(
                    value: progress == null || progress.$2 == 0
                        ? null
                        : progress.$1 / progress.$2,
                  ),
                ],
                if (problem != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    problem,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SwitchListTile(
            value: drive.auto.value,
            onChanged: (v) => unawaited(drive.setAuto(v)),
            title: Text('Back up automatically'.tr),
            subtitle: Text(
              'Also while the app is closed, often when the phone is charging'
                  .tr,
            ),
          ),
          if (drive.auto.value && !drive.backgroundAllowed.value)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.battery_alert_rounded,
                            color: colors.onTertiaryContainer,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              ('This phone\'s battery saving stops '
                                      'Locaproof when it is closed, so '
                                      'backup then cannot finish. In '
                                      'settings, open Battery and allow '
                                      'background activity.')
                                  .tr,
                              style: context.text.bodySmall?.copyWith(
                                color: colors.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () =>
                              unawaited(drive.openBackgroundSettings()),
                          child: Text('Open settings'.tr),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SwitchListTile(
            value: drive.wifiOnly.value,
            onChanged: (v) => unawaited(drive.setWifiOnly(v)),
            title: Text('Only on Wi-Fi'.tr),
            subtitle: Text('Saves mobile data; Back up now always works'.tr),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => _backUp(context),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text('Back up now'.tr),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _restore(context),
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: Text('Restore'.tr),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: busy ? null : () => _signOut(context),
              child: Text('Sign out'.tr),
            ),
          ),
        ],
      );
    });
  }

  static String _lastBackupText(DateTime? at) {
    if (at == null) return 'Not backed up yet'.tr;
    final local = at.toLocal();
    return 'Last backup: @date, @time'.trParams({
      'date': CaptureTimeFormatter.date(local),
      'time': CaptureTimeFormatter.time(local),
    });
  }

  Future<void> _backUp(BuildContext context) async {
    final result = await drive.backUpNow();
    if (result == null || !context.mounted) return;
    _snack(
      context,
      result.uploaded == 0
          ? 'Everything is already in Google Drive'.tr
          : '@n file backed up'.trCount('@n files backed up', result.uploaded, {
              'n': '${result.uploaded}',
            }),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const Icon(Icons.cloud_download_outlined),
        title: Text('Restore from Google Drive?'.tr),
        content: Text(
          ('Adds the photos, videos and projects in your Drive backup that '
                  'this phone does not have. Nothing on this phone is '
                  'replaced or deleted.')
              .tr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text('Restore'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await drive.restore();
    if (result == null || !context.mounted) return;
    _snack(
      context,
      result.addedFiles == 0
          ? 'This phone already has everything in the backup'.tr
          : 'Restored @n photo (@files files)'.trCount(
              'Restored @n photos (@files files)',
              result.addedPhotos,
              {'n': '${result.addedPhotos}', 'files': '${result.addedFiles}'},
            ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Stop Google Drive backup?'.tr),
        content: Text(
          ('New photos will no longer be backed up. What is already in your '
                  'Drive stays there.')
              .tr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text('Sign out'.tr),
          ),
        ],
      ),
    );
    if (confirmed == true) await drive.signOut();
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
