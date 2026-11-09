import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/app.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/constants/app_constants.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/gallery/views/gallery_view.dart';
import 'package:gps_camera/features/home/controllers/home_controller.dart';
import 'package:gps_camera/features/home/widgets/dashboard.dart';
import 'package:gps_camera/features/projects/views/projects_view.dart';
import 'package:gps_camera/features/reports/views/reports_view.dart';
import 'package:gps_camera/shared/widgets/responsive_center.dart';
import 'package:gps_camera/shared/widgets/soft_surface.dart';
import 'package:gps_camera/app/theme/soft_theme.dart';

/// The main screen: a tab bar along the bottom with the dashboard, gallery,
/// projects and reports. Only the shown tab is built; their controllers
/// stay, so selections and filters survive switching.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with RouteAware {
  HomeController get controller => Get.find<HomeController>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// Back from a screen opened on top (camera, a photo, settings...):
  /// what it changed shows at once.
  @override
  void didPopNext() => unawaited(controller.refreshCurrent());

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tab = controller.tab.value;
      final gallery = controller.gallery;
      // The gallery's own back handling (leaving selection or search) comes
      // first; otherwise back returns to the dashboard before leaving.
      final galleryBusy =
          tab == HomeTab.gallery &&
          (gallery.selecting.value || gallery.searching.value);
      return PopScope(
        canPop: tab == HomeTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !galleryBusy) controller.select(HomeTab.home);
        },
        child: Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(tab),
              child: switch (tab) {
                HomeTab.home => const _Dashboard(),
                HomeTab.gallery => const GalleryView(),
                HomeTab.projects => const ProjectsView(),
                HomeTab.reports => const ReportsView(),
              },
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab.index,
            onDestinationSelected: (i) => controller.select(HomeTab.values[i]),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: 'Home'.tr,
              ),
              NavigationDestination(
                icon: const Icon(Icons.photo_library_outlined),
                selectedIcon: const Icon(Icons.photo_library_rounded),
                label: 'Gallery'.tr,
              ),
              NavigationDestination(
                icon: const Icon(Icons.folder_outlined),
                selectedIcon: const Icon(Icons.folder_rounded),
                label: 'Projects'.tr,
              ),
              NavigationDestination(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                selectedIcon: const Icon(Icons.picture_as_pdf_rounded),
                label: 'Reports'.tr,
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _Dashboard extends GetView<HomeController> {
  const _Dashboard();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Row(
          children: [
            DecoratedBox(
              decoration: context.soft.card(radius: 12, depth: 3),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 26,
                  height: 26,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              AppConstants.appName,
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings'.tr,
            onPressed: controller.openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SoftBackdrop(
          child: ResponsiveCenter(
            child: RefreshIndicator(
              onRefresh: controller.refreshCurrent,
              child: Obx(() {
                final captures = controller.captures;
                final projects = controller.activeProjects;
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  children: [
                    CaptureCard(
                      onTap: controller.openCamera,
                      last: captures.firstOrNull,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            icon: Icons.photo_outlined,
                            color: AppColors.brand,
                            value: controller.photoCount,
                            label: 'Photos'.tr,
                            onTap: () => controller.select(HomeTab.gallery),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: StatTile(
                            icon: Icons.videocam_outlined,
                            color: AppColors.recording,
                            value: controller.videoCount,
                            label: 'Videos'.tr,
                            onTap: () => controller.select(HomeTab.gallery),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: StatTile(
                            icon: Icons.folder_outlined,
                            color: AppColors.success,
                            value: projects.length,
                            label: 'Projects'.tr,
                            onTap: () => controller.select(HomeTab.projects),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: StatTile(
                            icon: Icons.picture_as_pdf_outlined,
                            color: AppColors.accent,
                            value: controller.reportCount,
                            label: 'Reports'.tr,
                            onTap: () => controller.select(HomeTab.reports),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    DashboardSection(
                      title: 'Recent captures'.tr,
                      action: captures.isEmpty ? null : 'See all'.tr,
                      onAction: () => controller.select(HomeTab.gallery),
                      child: RecentCaptures(
                        photos: captures
                            .take(HomeController.recentCount)
                            .toList(),
                        onOpen: controller.openPhoto,
                        onCamera: controller.openCamera,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    DashboardSection(
                      title: 'Active projects'.tr,
                      action: projects.isEmpty ? null : 'See all'.tr,
                      onAction: () => controller.select(HomeTab.projects),
                      child: RecentProjects(
                        projects: projects
                            .take(HomeController.projectCount)
                            .toList(),
                        coverPath: controller.projects.coverPath,
                        onOpen: controller.openProject,
                        onCreate: controller.createProject,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
