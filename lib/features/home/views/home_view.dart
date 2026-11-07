import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/constants/app_constants.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/home/controllers/home_controller.dart';
import 'package:gps_camera/features/home/widgets/capture_hero_card.dart';
import 'package:gps_camera/features/home/widgets/quick_action_card.dart';
import 'package:gps_camera/shared/widgets/responsive_center.dart';
import 'package:gps_camera/shared/widgets/section_header.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      QuickActionCard(
        icon: Icons.photo_library_outlined,
        title: 'Gallery',
        subtitle: 'Browse geo-tagged photos',
        onTap: controller.openGallery,
      ),
      QuickActionCard(
        icon: Icons.folder_outlined,
        title: 'Projects',
        subtitle: 'Organise photos by site or client',
        onTap: controller.openProjects,
      ),
      QuickActionCard(
        icon: Icons.picture_as_pdf_outlined,
        title: 'Reports',
        subtitle: 'PDF reports you have created',
        onTap: controller.openReports,
      ),
      QuickActionCard(
        icon: Icons.tune_rounded,
        title: 'Settings',
        subtitle: 'Appearance and preferences',
        onTap: controller.openSettings,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: controller.openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: ListView(
            padding: AppSpacing.page,
            children: [
              Text(
                'Document every site with verifiable location data.',
                style: context.text.bodyLarge?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              CaptureHeroCard(onTap: controller.openCamera),
              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader('Workspace'),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: context.isCompactWidth ? 2 : 3,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisExtent: 148,
                ),
                itemBuilder: (_, index) => actions[index],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
