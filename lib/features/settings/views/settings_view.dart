import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/constants/app_constants.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/settings/controllers/settings_controller.dart';
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
