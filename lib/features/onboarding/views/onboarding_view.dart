import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/core/services/permission_service.dart';
import 'package:gps_camera/features/onboarding/controllers/onboarding_controller.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';

class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Obx(
                    () => AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: controller.isLastPage ? 0 : 1,
                      child: TextButton(
                        onPressed: controller.isLastPage
                            ? null
                            : () => controller.finish(),
                        child: const Text('Skip'),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: controller.pages,
                    onPageChanged: controller.onPageChanged,
                    children: [
                      const _WelcomePage(),
                      _PermissionsPage(controller: controller),
                      const _ReadyPage(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: Obx(
                    () => Column(
                      children: [
                        _Dots(
                          count: OnboardingController.pageCount,
                          index: controller.page.value,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (controller.isLastPage) ...[
                          AppButton(
                            label: 'Open camera',
                            icon: Icons.photo_camera_outlined,
                            isExpanded: true,
                            onPressed: () =>
                                controller.finish(openCamera: true),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            label: 'Go to home',
                            variant: AppButtonVariant.secondary,
                            isExpanded: true,
                            onPressed: () => controller.finish(),
                          ),
                        ] else
                          AppButton(
                            label: 'Next',
                            icon: Icons.arrow_forward_rounded,
                            isExpanded: true,
                            onPressed: controller.next,
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
}

class _Page extends StatelessWidget {
  const _Page({
    required this.icon,
    required this.title,
    required this.message,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: AppColors.accent),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          title,
          textAlign: TextAlign.center,
          style: context.text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ...children,
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.primary),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(text, style: context.text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return const _Page(
      icon: Icons.photo_camera_outlined,
      title: 'Welcome to GPS Camera',
      message: 'Photos that prove where and when they were taken.',
      children: [
        _Feature(
          Icons.branding_watermark_outlined,
          'Location stamp',
          'Address, map, coordinates, time and direction on every photo. '
              'The original is always kept too.',
        ),
        _Feature(
          Icons.folder_outlined,
          'Projects and reports',
          'Group photos by site or client and share them as a PDF report.',
        ),
        _Feature(
          Icons.cloud_off_outlined,
          'Works offline',
          'Photos, GPS and reports work without internet. Addresses and '
              'maps are added once you are online.',
        ),
      ],
    );
  }
}

class _PermissionsPage extends StatelessWidget {
  const _PermissionsPage({required this.controller});

  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return _Page(
      icon: Icons.verified_user_outlined,
      title: 'Two permissions',
      message: 'Allow these now, or later when you open the camera.',
      children: [
        Obx(
          () => _PermissionCard(
            icon: Icons.photo_camera_outlined,
            title: 'Camera',
            reason: 'To take photos.',
            access: controller.camera.value,
            onAllow: controller.requestCamera,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Obx(
          () => _PermissionCard(
            icon: Icons.location_on_outlined,
            title: 'Location',
            reason:
                'To record where each photo was taken. Only used while '
                'the app is open. Without it, photos have no location.',
            access: controller.location.value,
            onAllow: controller.requestLocation,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 20,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Your photos stay on this phone. To show an address and a '
                'map, only the photo’s coordinates are sent to the address '
                'and map services.',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.reason,
    required this.access,
    required this.onAllow,
  });

  final IconData icon;
  final String title;
  final String reason;
  final PermissionAccess? access;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final granted = access == PermissionAccess.granted;
    final blocked = access == PermissionAccess.blocked;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(icon, color: context.colors.primary),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    blocked
                        ? '$reason Turned off — allow it in system settings.'
                        : reason,
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            if (granted)
              Semantics(
                label: '$title allowed',
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
              )
            else
              FilledButton.tonal(
                onPressed: onAllow,
                child: Text(blocked ? 'Settings' : 'Allow'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReadyPage extends StatelessWidget {
  const _ReadyPage();

  @override
  Widget build(BuildContext context) {
    return const _Page(
      icon: Icons.check_rounded,
      title: 'You’re ready',
      message: 'A few things worth knowing:',
      children: [
        _Feature(
          Icons.photo_library_outlined,
          'Phone gallery',
          'Watermarked photos are also saved to Pictures/GPS Camera. '
              'Change this in Settings.',
        ),
        _Feature(
          Icons.sticky_note_2_outlined,
          'Notes and branding',
          'Add a note in the camera, and your own name or logo in the '
              'watermark editor.',
        ),
        _Feature(
          Icons.backup_outlined,
          'Back up',
          'Settings → Backup keeps all photos and projects in one file.',
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${index + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index
                    ? context.colors.primary
                    : context.colors.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
