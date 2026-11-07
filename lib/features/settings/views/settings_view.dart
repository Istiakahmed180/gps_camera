import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/constants/app_constants.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/export/models/gallery_save_mode.dart';
import 'package:gps_camera/features/settings/controllers/settings_controller.dart';
import 'package:gps_camera/features/settings/widgets/backup_actions.dart';
import 'package:gps_camera/features/settings/widgets/settings_sections.dart';
import 'package:gps_camera/features/settings/widgets/theme_mode_selector.dart';
import 'package:gps_camera/shared/widgets/responsive_center.dart';
import 'package:gps_camera/shared/widgets/section_header.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: ListView(
            padding: AppSpacing.page,
            children: [
              const SectionHeader('Camera'),
              Card(child: CameraSettings(controller: controller)),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Time and units'),
              Card(child: DisplaySettings(controller: controller)),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Phone gallery'),
              Card(child: _GallerySettings(controller: controller)),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Location details'),
              Card(child: LocationDetailsSettings(controller: controller)),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Storage'),
              Card(child: StorageSettings(controller: controller)),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Backup'),
              Card(child: BackupActions(service: controller.backup)),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Appearance'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Theme', style: context.text.titleMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Choose how the app looks outside the camera.',
                        style: context.text.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Obx(
                        () => ThemeModeSelector(
                          selected: controller.themeMode.value,
                          onChanged: controller.changeThemeMode,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('About'),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text(AppConstants.appName),
                  subtitle: Text('Geo-tagged photos, albums and reports'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GallerySettings extends StatelessWidget {
  const _GallerySettings({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final available = controller.galleryAvailable.value;
      // The check is a quick platform call; show nothing until it answers.
      if (available == null) return const SizedBox(height: 72);
      if (!available) {
        return const ListTile(
          leading: Icon(Icons.info_outline_rounded),
          title: Text('Not available on this phone'),
          subtitle: Text(
            'Saving to the phone gallery needs Android 10 or later. Use '
            'Share or Backup to keep copies outside the app.',
          ),
        );
      }

      final mode = controller.gallerySaveMode.value;
      final progress = controller.galleryProgress.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              'New photos are also saved to Pictures/GPS Camera, so they '
              'appear in the phone’s gallery and stay there if the app is '
              'removed.',
              style: context.text.bodySmall,
            ),
          ),
          RadioGroup<GallerySaveMode>(
            groupValue: mode,
            onChanged: (value) {
              if (value != null) controller.setGallerySaveMode(value);
            },
            child: Column(
              children: [
                for (final option in GallerySaveMode.values)
                  RadioListTile<GallerySaveMode>(
                    value: option,
                    title: Text(option.label),
                    subtitle: Text(option.description),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Copy existing photos to gallery'),
            subtitle: Text(
              progress == null
                  ? 'Uses the choice above. Photos already copied are '
                        'skipped.'
                  : progress.total == 0
                  ? 'Preparing…'
                  : 'Copying ${progress.done} of ${progress.total}…',
            ),
            trailing: progress == null
                ? null
                : const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
            enabled: mode != GallerySaveMode.off && progress == null,
            onTap: () => _copyExisting(context),
          ),
        ],
      );
    });
  }

  Future<void> _copyExisting(BuildContext context) async {
    final count = await controller.existingToCopy();
    if (!context.mounted) return;
    if (count == null) {
      _snack(context, 'Photos could not be read. Try again.', isError: true);
      return;
    }
    if (count == 0) {
      _snack(context, 'There are no photos to copy.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Copy to phone gallery?'),
        content: Text(
          '$count photo${count == 1 ? '' : 's'} will be copied to '
          'Pictures/GPS Camera. The photos in the app are not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Copy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final summary = await controller.copyExistingToGallery();
    if (!context.mounted) return;
    if (summary == null) {
      _snack(context, 'Photos could not be copied. Try again.', isError: true);
      return;
    }
    final parts = [
      '${summary.saved} copied',
      if (summary.alreadyThere > 0) '${summary.alreadyThere} already there',
      if (summary.failed > 0) '${summary.failed} failed',
    ];
    _snack(context, parts.join(' · '), isError: summary.failed > 0);
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
