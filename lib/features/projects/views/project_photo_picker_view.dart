import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/widgets/photo_grid.dart';
import 'package:gps_camera/features/projects/controllers/project_photo_picker_controller.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';
import 'package:gps_camera/shared/widgets/empty_state_view.dart';

class ProjectPhotoPickerView extends GetView<ProjectPhotoPickerController> {
  const ProjectPhotoPickerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add photos'.tr)),
      body: Obx(() {
        switch (controller.status.value) {
          case PhotoPickerStatus.loading:
            return const Center(child: CircularProgressIndicator());
          case PhotoPickerStatus.error:
            return EmptyStateView(
              icon: Icons.error_outline_rounded,
              title: 'Photos could not be loaded'.tr,
              message: 'Try again.'.tr,
              action: AppButton(
                label: 'Try again'.tr,
                variant: AppButtonVariant.secondary,
                onPressed: controller.load,
              ),
            );
          case PhotoPickerStatus.ready:
            break;
        }
        if (controller.originals.isEmpty) {
          return EmptyStateView(
            icon: Icons.photo_library_outlined,
            title: 'No photos yet'.tr,
            message: 'Capture photos first, then add them to this project.'.tr,
          );
        }
        controller.selected.length;
        controller.assignments.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                ('Choose original photos. Their watermarked copies are '
                        'included automatically.')
                    .tr,
                style: context.text.bodySmall,
              ),
            ),
            Expanded(
              child: PhotoGrid(
                photos: controller.originals,
                index: controller.index.value,
                onOpen: controller.toggle,
                overlayBuilder: (photo) =>
                    _Overlay(photo: photo, controller: controller),
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        final count = controller.selected.length;
        final moving = controller.movingCount;
        return Material(
          color: context.colors.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: AppSpacing.page,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (controller.error.value != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        controller.error.value!,
                        style: TextStyle(color: context.colors.error),
                      ),
                    ),
                  if (moving > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        '@n will move from another project.'.trParams({
                          'n': '$moving',
                        }),
                        style: context.text.bodySmall,
                      ),
                    ),
                  AppButton(
                    label: count == 0
                        ? 'Select photos'.tr
                        : 'Add @n photo'.trPluralParams(
                            'Add @n photos',
                            count,
                            {'n': '$count'},
                          ),
                    icon: Icons.check_rounded,
                    isExpanded: true,
                    isLoading: controller.isSaving.value,
                    onPressed: count == 0 ? null : controller.save,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.photo, required this.controller});

  final GalleryPhoto photo;
  final ProjectPhotoPickerController controller;

  @override
  Widget build(BuildContext context) {
    final inThis = controller.isInThisProject(photo);
    final selected = controller.isSelected(photo);
    final other = inThis ? null : controller.projectOf(photo);
    final colors = context.colors;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (inThis || selected)
          DecoratedBox(
            decoration: BoxDecoration(
              color: inThis
                  ? const Color(0x99000000)
                  : colors.primary.withValues(alpha: 0.25),
              borderRadius: AppRadius.mdAll,
              border: selected
                  ? Border.all(color: colors.primary, width: 3)
                  : null,
            ),
          ),
        Positioned(
          right: AppSpacing.sm,
          top: AppSpacing.sm,
          child: Icon(
            inThis || selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: inThis
                ? AppColors.onViewfinderMuted
                : AppColors.onViewfinder,
          ),
        ),
        if (inThis)
          Center(
            child: Text(
              'Added'.tr,
              style: const TextStyle(
                color: AppColors.onViewfinder,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else if (other != null)
          Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            top: 30,
            child: Text(
              'In @name'.trParams({'name': other.name}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
