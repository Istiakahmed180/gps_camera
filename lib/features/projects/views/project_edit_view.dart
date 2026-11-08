import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/projects/controllers/project_edit_controller.dart';
import 'package:gps_camera/features/projects/models/photo_refs.dart';
import 'package:gps_camera/features/projects/services/project_repository.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';
import 'package:gps_camera/shared/widgets/responsive_center.dart';
import 'package:gps_camera/shared/widgets/section_header.dart';

class ProjectEditView extends GetView<ProjectEditController> {
  const ProjectEditView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isNew ? 'New project'.tr : 'Edit project'.tr),
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: AppSpacing.page,
          children: [
            Obx(
              () => TextField(
                controller: controller.name,
                autofocus: controller.isNew,
                maxLength: ProjectRepository.maxNameLength,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onChanged: (_) => controller.clearNameError(),
                decoration: InputDecoration(
                  labelText: 'Project name'.tr,
                  hintText: 'e.g. North Bridge inspection'.tr,
                  errorText: controller.nameError.value,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller.description,
              maxLines: 4,
              minLines: 2,
              maxLength: ProjectRepository.maxDescriptionLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Description (optional)'.tr,
                alignLabelWithHint: true,
              ),
            ),
            if (!controller.isNew) ...[
              const SizedBox(height: AppSpacing.lg),
              SectionHeader('Cover photo'.tr),
              const _CoverPicker(),
            ],
            Obx(
              () => controller.formError.value == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: Text(
                        controller.formError.value!,
                        style: TextStyle(color: context.colors.error),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Obx(
              () => AppButton(
                label: controller.isNew
                    ? 'Create project'.tr
                    : 'Save changes'.tr,
                isExpanded: true,
                isLoading: controller.isSaving.value,
                onPressed: controller.save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPicker extends GetView<ProjectEditController> {
  const _CoverPicker();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: controller.rootPath(),
      builder: (context, _) => Obx(() {
        final options = controller.coverOptions;
        if (options.isEmpty) {
          return Text(
            ('Add photos to this project to choose a cover. Until then, the '
                    'latest photo is used.')
                .tr,
            style: context.text.bodySmall,
          );
        }
        final selected = controller.coverRef.value;
        return SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _CoverOption(
                selected: selected == null,
                onTap: () => controller.selectCover(null),
                child: Center(child: Text('Latest'.tr)),
              ),
              for (final photo in options)
                _CoverOption(
                  selected: selected == PhotoRefs.of(photo),
                  onTap: () => controller.selectCover(photo),
                  child: _Thumb(photo: photo),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo});

  final GalleryPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      photo.file,
      fit: BoxFit.cover,
      cacheWidth: (88 * MediaQuery.devicePixelRatioOf(context)).round(),
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
    );
  }
}

class _CoverOption extends StatelessWidget {
  const _CoverOption({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 88,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
