import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/count_text.dart';
import 'package:gps_camera/app/i18n/app_language.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
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
      appBar: AppBar(title: Text('Settings'.tr)),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: ListView(
            padding: AppSpacing.page,
            children: [
              SectionHeader('Camera'.tr),
              Card(child: CameraSettings(controller: controller)),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader('Time and units'.tr),
              Card(child: DisplaySettings(controller: controller)),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader('Phone gallery'.tr),
              Card(child: _GallerySettings(controller: controller)),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader('Location details'.tr),
              Card(child: LocationDetailsSettings(controller: controller)),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader('Storage'.tr),
              Card(child: StorageSettings(controller: controller)),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader('Backup'.tr),
              Card(child: BackupActions(service: controller.backup)),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader('Appearance'.tr),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Theme'.tr, style: context.text.titleMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Choose how the app looks outside the camera.'.tr,
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
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Obx(
                  () => ListTile(
                    leading: const Icon(Icons.translate_rounded),
                    title: Text('Language'.tr),
                    subtitle: Text(
                      controller.language.value == AppLanguage.system
                          ? '@language (phone language)'.trParams({
                              'language': controller.phoneLanguage.label,
                            })
                          : controller.language.value.label,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Get.toNamed<void>(AppRoutes.language),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader('About'.tr),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text(AppConstants.appName),
                  subtitle: Text('Geo-tagged photos, albums and reports'.tr),
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
        return ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: Text('Not available on this phone'.tr),
          subtitle: Text(
            ('Saving to the phone gallery needs Android 10 or later. Use '
                    'Share or Backup to keep copies outside the app.')
                .tr,
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
              ('New photos are also saved to Pictures/GPS Camera, so they '
                      'appear in the phone’s gallery and stay there if the app '
                      'is removed.')
                  .tr,
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
                    title: Text(option.label.tr),
                    subtitle: Text(option.description.tr),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text('Copy existing photos to gallery'.tr),
            subtitle: Text(
              progress == null
                  ? 'Uses the choice above. Photos already copied are skipped.'
                        .tr
                  : progress.total == 0
                  ? 'Preparing…'.tr
                  : 'Copying @done of @total…'.trParams({
                      'done': '${progress.done}',
                      'total': '${progress.total}',
                    }),
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
      _snack(context, 'Photos could not be read. Try again.'.tr, isError: true);
      return;
    }
    if (count == 0) {
      _snack(context, 'There are no photos to copy.'.tr);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Copy to phone gallery?'.tr),
        content: Text(
          ('@n photo will be copied to Pictures/GPS Camera. The photos in '
                  'the app are not changed.')
              .trCount(
                '@n photos will be copied to Pictures/GPS Camera. The '
                'photos in the app are not changed.',
                count,
                {'n': '$count'},
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text('Copy'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final summary = await controller.copyExistingToGallery();
    if (!context.mounted) return;
    if (summary == null) {
      _snack(
        context,
        'Photos could not be copied. Try again.'.tr,
        isError: true,
      );
      return;
    }
    final parts = [
      '@n copied'.trParams({'n': '${summary.saved}'}),
      if (summary.alreadyThere > 0)
        '@n already there'.trParams({'n': '${summary.alreadyThere}'}),
      if (summary.failed > 0) '@n failed'.trParams({'n': '${summary.failed}'}),
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
