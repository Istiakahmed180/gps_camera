import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/features/gallery/widgets/gallery_filter_bar.dart';
import 'package:gps_camera/features/gallery/widgets/photo_grid.dart';
import 'package:gps_camera/features/projects/controllers/project_details_controller.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';
import 'package:gps_camera/shared/widgets/empty_state_view.dart';

enum _MenuAction { archive, restore, delete }

class ProjectDetailsView extends GetView<ProjectDetailsController> {
  const ProjectDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final project = controller.project.value;
      return Scaffold(
        appBar: AppBar(
          title: Text(project?.name ?? 'Project'),
          actions: [
            if (project != null) ...[
              IconButton(
                tooltip: 'Edit project',
                onPressed: controller.isBusy.value ? null : controller.edit,
                icon: const Icon(Icons.edit_outlined),
              ),
              PopupMenuButton<_MenuAction>(
                tooltip: 'More',
                enabled: !controller.isBusy.value,
                onSelected: (a) => _onMenu(context, a),
                itemBuilder: (_) => [
                  if (project.isArchived)
                    const PopupMenuItem(
                      value: _MenuAction.restore,
                      child: ListTile(
                        leading: Icon(Icons.unarchive_outlined),
                        title: Text('Restore project'),
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: _MenuAction.archive,
                      child: ListTile(
                        leading: Icon(Icons.archive_outlined),
                        title: Text('Archive project'),
                      ),
                    ),
                  PopupMenuItem(
                    value: _MenuAction.delete,
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: context.colors.error,
                      ),
                      title: Text(
                        'Delete project',
                        style: TextStyle(color: context.colors.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        floatingActionButton: project == null || project.isArchived
            ? null
            : FloatingActionButton.extended(
                onPressed: controller.addPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add photos'),
              ),
        body: _body(context),
      );
    });
  }

  Widget _body(BuildContext context) {
    switch (controller.status.value) {
      case ProjectDetailsStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ProjectDetailsStatus.missing:
        return const EmptyStateView(
          icon: Icons.folder_off_outlined,
          title: 'Project not found',
          message: 'This project was deleted.',
        );
      case ProjectDetailsStatus.error:
        return EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'Project could not be loaded',
          message: 'Try again.',
          action: AppButton(
            label: 'Try again',
            variant: AppButtonVariant.secondary,
            onPressed: controller.reload,
          ),
        );
      case ProjectDetailsStatus.ready:
        break;
    }

    final project = controller.project.value!;
    final photos = controller.visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (project.isArchived)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Chip(
                    avatar: Icon(Icons.archive_outlined, size: 18),
                    label: Text('Archived · restore to add photos'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (project.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    project.description,
                    style: context.text.bodyMedium,
                  ),
                ),
              Text(
                'Created ${PhotoInfoFormatter.instant(project.createdAt)}',
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${controller.originalCount} original'
                '${controller.originalCount == 1 ? '' : 's'} · '
                '${controller.watermarkedCount} watermarked',
                style: context.text.labelLarge,
              ),
              if (controller.missingCount > 0)
                Text(
                  '${controller.missingCount} assigned photo files are missing',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.error,
                  ),
                ),
            ],
          ),
        ),
        if (!controller.index.value.isEmpty)
          GalleryFilterBar(
            selected: controller.filter.value,
            index: controller.index.value,
            onChanged: controller.setFilter,
          ),
        Expanded(
          child: controller.index.value.isEmpty
              ? EmptyStateView(
                  icon: Icons.photo_library_outlined,
                  title: 'No photos in this project',
                  message: project.isArchived
                      ? 'Restore the project to add photos.'
                      : 'Add existing photos, or choose this project on the '
                            'camera screen so new photos are added '
                            'automatically.',
                )
              : RefreshIndicator(
                  onRefresh: controller.reload,
                  child: PhotoGrid(
                    photos: photos,
                    index: controller.index.value,
                    onOpen: controller.openPhoto,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      96,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _onMenu(BuildContext context, _MenuAction action) async {
    final project = controller.project.value;
    if (project == null) return;
    switch (action) {
      case _MenuAction.archive:
      case _MenuAction.restore:
        final archiving = action == _MenuAction.archive;
        final error = await controller.setArchived(archiving);
        if (!context.mounted) return;
        _snack(
          context,
          error ??
              (archiving
                  ? '${project.name} archived'
                  : '${project.name} restored'),
          isError: error != null,
        );
      case _MenuAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: context.colors.error,
            ),
            title: Text('Delete "${project.name}"?'),
            content: Text(
              'The project and its photo assignments will be removed. '
              '${switch (controller.originalCount) {
                0 => '',
                1 => 'Its photo stays in the gallery. ',
                final n => 'Its $n photos stay in the gallery. ',
              }}'
              'No photo files are deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.error,
                  foregroundColor: context.colors.onError,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete project'),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        final error = await controller.delete();
        if (!context.mounted) return;
        if (error == null) {
          Get.back<void>();
          _snack(Get.context ?? context, '${project.name} deleted');
        } else {
          _snack(context, error, isError: true);
        }
    }
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
