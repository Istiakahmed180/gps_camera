import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/count_text.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/backup/services/backup_service.dart';
import 'package:gps_camera/features/watermark/services/logo_service.dart';

/// Create backup / Restore from backup tiles with their dialogs.
class BackupActions extends StatelessWidget {
  const BackupActions({super.key, required this.service});

  final BackupService service;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final busy = service.isBusy.value;
      return Column(
        children: [
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text('Create backup'.tr),
            subtitle: Text(
              ('One ZIP file with all photos, watermarked copies, maps, '
                      'reports, projects and watermark settings. Save it to '
                      'Files, Google Drive or a computer.')
                  .tr,
            ),
            enabled: !busy,
            onTap: () => _create(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore_rounded),
            title: Text('Restore from backup'.tr),
            subtitle: Text(
              ('Adds what is missing from a backup. Nothing on this phone is '
                      'replaced or deleted.')
                  .tr,
            ),
            enabled: !busy,
            onTap: () => _restore(context),
          ),
        ],
      );
    });
  }

  Future<void> _create(BuildContext context) async {
    final navigator = Navigator.of(context);
    _progressDialog(
      context,
      'Creating backup'.tr,
      'Adding file @done of @total',
    );
    BackupFile backup;
    try {
      backup = await service.create();
    } on BackupException catch (e) {
      navigator.pop();
      if (context.mounted) _snack(context, e.message.tr, isError: true);
      return;
    }
    navigator.pop();

    try {
      final outcome = await service.saveToDevice(backup);
      if (!context.mounted) return;
      switch (outcome) {
        case BackupSaveOutcome.saved:
          _snack(
            context,
            'Backup saved: @n photo, @files files'.trCount(
              'Backup saved: @n photos, @files files',
              backup.photoCount,
              {'n': '${backup.photoCount}', 'files': '${backup.fileCount}'},
            ),
          );
        case BackupSaveOutcome.cancelled:
          _snack(context, 'Backup not saved'.tr);
        case BackupSaveOutcome.noApp:
          _snack(
            context,
            'No app can save files on this phone.'.tr,
            isError: true,
          );
        case BackupSaveOutcome.failed:
          _snack(
            context,
            'The backup could not be saved there. Try another location.'.tr,
            isError: true,
          );
      }
    } finally {
      await service.discard(backup.file);
    }
  }

  Future<void> _restore(BuildContext context) async {
    final picked = await _guard(context, service.pick);
    if (picked == null || !context.mounted) return;
    await restoreFile(context, picked);
  }

  /// Confirms, restores [picked] with progress, shows the result and then
  /// removes the private copy. [afterRestart] explains that the file was
  /// chosen before Android restarted the app.
  Future<void> restoreFile(
    BuildContext context,
    File picked, {
    bool afterRestart = false,
  }) async {
    final navigator = Navigator.of(context);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          icon: const Icon(Icons.settings_backup_restore_rounded),
          title: Text('Restore this backup?'.tr),
          content: Text(
            '${afterRestart ? '${'You chose this backup just before Android restarted the app.'.tr} ' : ''}'
            '${('Photos, watermarked copies, maps, reports and projects that '
                'are not on this phone yet will be added. Files and '
                'projects already here stay exactly as they are.').tr}',
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
      if (confirmed != true || !context.mounted) return;

      _progressDialog(
        context,
        'Restoring backup'.tr,
        'Checking file @done of @total',
      );
      RestoreSummary summary;
      try {
        summary = await service.restore(picked);
      } on BackupException catch (e) {
        navigator.pop();
        if (context.mounted) _snack(context, e.message.tr, isError: true);
        return;
      }
      navigator.pop();
      // A restored logo should show up without restarting the app.
      if (Get.isRegistered<LogoService>()) {
        unawaited(Get.find<LogoService>().reload());
      }
      if (context.mounted) await _showSummary(context, summary);
    } finally {
      await service.discard(picked);
    }
  }

  Future<T?> _guard<T>(BuildContext context, Future<T?> Function() run) async {
    try {
      return await run();
    } on BackupException catch (e) {
      if (context.mounted) _snack(context, e.message.tr, isError: true);
      return null;
    }
  }

  /// [step] is an untranslated key with `@done` and `@total`.
  void _progressDialog(BuildContext context, String title, String step) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(title),
          content: Obx(() {
            final p = service.progress.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: p == null || p.total == 0 ? null : p.fraction,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  p == null || p.total == 0
                      ? 'Preparing…'.tr
                      : step.trParams({
                          'done': '${p.done}',
                          'total': '${p.total}',
                        }),
                  style: dialog.text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Keep the app open until this finishes.'.tr,
                  style: dialog.text.bodySmall,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Future<void> _showSummary(BuildContext context, RestoreSummary s) {
    String files(int n) => '@n file'.trCount('@n files', n, {'n': '$n'});
    final nothing = s.addedFiles == 0 && s.addedProjects == 0;
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline_rounded),
        title: Text((nothing ? 'Already up to date' : 'Backup restored').tr),
        content: Text(
          [
            if (nothing)
              'Everything in this backup is already on this phone.'.tr
            else ...[
              'Added @n photo (@files in total).'.trCount(
                'Added @n photos (@files in total).',
                s.addedPhotos,
                {'n': '${s.addedPhotos}', 'files': files(s.addedFiles)},
              ),
              if (s.addedProjects > 0)
                'Added @n project.'.trCount(
                  'Added @n projects.',
                  s.addedProjects,
                  {'n': '${s.addedProjects}'},
                ),
              if (s.addedAssignments > 0)
                '@n photo put back in their projects.'.trCount(
                  '@n photos put back in their projects.',
                  s.addedAssignments,
                  {'n': '${s.addedAssignments}'},
                ),
              if (s.restoredSettings) 'Watermark settings restored.'.tr,
            ],
            if (s.skippedFiles > 0)
              '@n file skipped because they already exist.'.trCount(
                '@n files skipped because they already exist.',
                s.skippedFiles,
                {'n': '${s.skippedFiles}'},
              ),
          ].join('\n\n'),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text('Done'.tr),
          ),
        ],
      ),
    );
  }

  static void _snack(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? context.colors.error : null,
      ),
    );
  }
}
