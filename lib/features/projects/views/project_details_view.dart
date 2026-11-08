import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/features/gallery/widgets/gallery_filter_bar.dart';
import 'package:gps_camera/features/gallery/widgets/photo_grid.dart';
import 'package:gps_camera/features/projects/controllers/project_details_controller.dart';
import 'package:gps_camera/features/projects/widgets/project_zip_share.dart';
import 'package:gps_camera/features/reports/services/report_service.dart';
import 'package:gps_camera/features/reports/widgets/report_generation.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';
import 'package:gps_camera/shared/widgets/empty_state_view.dart';

enum _MenuAction { shareZip, archive, restore, delete }

class ProjectDetailsView extends GetView<ProjectDetailsController> {
  const ProjectDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final project = controller.project.value;
      return Scaffold(
        appBar: AppBar(
          title: Text(project?.name ?? 'Project'.tr),
          actions: [
            if (project != null) ...[
              IconButton(
                tooltip: 'Create PDF report'.tr,
                onPressed: controller.isBusy.value
                    ? null
                    : () => _createReport(context),
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
              IconButton(
                tooltip: 'Edit project'.tr,
                onPressed: controller.isBusy.value ? null : controller.edit,
                icon: const Icon(Icons.edit_outlined),
              ),
              PopupMenuButton<_MenuAction>(
                tooltip: 'More'.tr,
                enabled: !controller.isBusy.value,
                onSelected: (a) => _onMenu(context, a),
                itemBuilder: (_) => [
                  if (controller.originalCount > 0)
                    PopupMenuItem(
                      value: _MenuAction.shareZip,
                      child: ListTile(
                        leading: const Icon(Icons.folder_zip_outlined),
                        title: Text('Share photos as ZIP'.tr),
                      ),
                    ),
                  if (project.isArchived)
                    PopupMenuItem(
                      value: _MenuAction.restore,
                      child: ListTile(
                        leading: const Icon(Icons.unarchive_outlined),
                        title: Text('Restore project'.tr),
                      ),
                    )
                  else
                    PopupMenuItem(
                      value: _MenuAction.archive,
                      child: ListTile(
                        leading: const Icon(Icons.archive_outlined),
                        title: Text('Archive project'.tr),
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
                        'Delete project'.tr,
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
                label: Text('Add photos'.tr),
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
        return EmptyStateView(
          icon: Icons.folder_off_outlined,
          title: 'Project not found'.tr,
          message: 'This project was deleted.'.tr,
        );
      case ProjectDetailsStatus.error:
        return EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'Project could not be loaded'.tr,
          message: 'Try again.'.tr,
          action: AppButton(
            label: 'Try again'.tr,
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
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Chip(
                    avatar: const Icon(Icons.archive_outlined, size: 18),
                    label: Text('Archived · restore to add photos'.tr),
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
                'Created @date'.trParams({
                  'date': PhotoInfoFormatter.instant(project.createdAt),
                }),
                style: context.text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${'@n original'.trPluralParams('@n originals', controller.originalCount, {'n': '${controller.originalCount}'})} · '
                '${'@n watermarked'.trParams({'n': '${controller.watermarkedCount}'})}',
                style: context.text.labelLarge,
              ),
              if (controller.missingCount > 0)
                Text(
                  '@n assigned photo files are missing'.trParams({
                    'n': '${controller.missingCount}',
                  }),
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
                  title: 'No photos in this project'.tr,
                  message: project.isArchived
                      ? 'Restore the project to add photos.'.tr
                      : ('Add existing photos, or choose this project on the '
                                'camera screen so new photos are added '
                                'automatically.')
                            .tr,
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

  Future<void> _createReport(BuildContext context) async {
    final job = controller.reportJob();
    if (job == null) {
      _snack(context, 'Add photos to this project to create a report.'.tr);
      return;
    }
    await generateReportWithProgress(context, Get.find<ReportService>(), job);
  }

  Future<void> _onMenu(BuildContext context, _MenuAction action) async {
    final project = controller.project.value;
    if (project == null) return;
    switch (action) {
      case _MenuAction.shareZip:
        await shareProjectZip(
          context,
          projectName: project.name,
          index: controller.index.value,
        );
      case _MenuAction.archive:
      case _MenuAction.restore:
        final archiving = action == _MenuAction.archive;
        final error = await controller.setArchived(archiving);
        if (!context.mounted) return;
        _snack(
          context,
          error ??
              (archiving
                  ? '@name archived'.trParams({'name': project.name})
                  : '@name restored'.trParams({'name': project.name})),
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
            title: Text('Delete "@name"?'.trParams({'name': project.name})),
            content: Text(
              [
                'The project and its photo assignments will be removed.'.tr,
                ...switch (controller.originalCount) {
                  0 => <String>[],
                  1 => ['Its photo stays in the gallery.'.tr],
                  final n => [
                    'Its @n photos stay in the gallery.'.trParams({'n': '$n'}),
                  ],
                },
                'No photo files are deleted.'.tr,
              ].join(' '),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'.tr),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.error,
                  foregroundColor: context.colors.onError,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Delete project'.tr),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        final error = await controller.delete();
        if (!context.mounted) return;
        if (error == null) {
          Get.back<void>();
          _snack(
            Get.context ?? context,
            '@name deleted'.trParams({'name': project.name}),
          );
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
