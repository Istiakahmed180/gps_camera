import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/gallery/controllers/photo_details_controller.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/features/gallery/widgets/photo_action_menu.dart';
import 'package:gps_camera/features/gallery/widgets/photo_details_panel.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/widgets/project_picker_sheet.dart';
import 'package:gps_camera/shared/widgets/note_dialog.dart';
import 'package:gps_camera/shared/widgets/section_header.dart';

class PhotoDetailsView extends GetView<PhotoDetailsController> {
  const PhotoDetailsView({super.key, required this.photo});

  final GalleryPhoto photo;

  @override
  String? get tag => photo.id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(photo.isOriginal ? 'Original'.tr : 'Watermarked copy'.tr),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Delete'.tr,
              onPressed: controller.isBusy.value
                  ? null
                  : () => _delete(context),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= AppBreakpoints.medium;
          final preview = _Preview(photo: photo);
          final details = Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NoteSection(controller: controller),
                PhotoDetailsPanel(
                  photo: photo,
                  dimensions: controller.dimensions.value,
                  related: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProjectSection(controller: controller),
                      _Related(controller: controller),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (wide) {
            return Row(
              children: [
                Expanded(child: preview),
                SizedBox(
                  width: 420,
                  child: ListView(
                    padding: AppSpacing.page,
                    children: [details],
                  ),
                ),
              ],
            );
          }
          return ListView(
            children: [
              SizedBox(height: constraints.maxHeight * 0.55, child: preview),
              Padding(padding: AppSpacing.page, child: details),
            ],
          );
        },
      ),
      bottomNavigationBar: Obx(
        () => PhotoActionBar(
          isOriginal: photo.isOriginal,
          hasSource: controller.source != null,
          isBusy: controller.isBusy.value,
          onShare: () => _share(context),
          onWatermark: controller.openWatermarkEditor,
          onOpenOriginal: () {
            final source = controller.source;
            if (source != null) controller.openRelated(source);
          },
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final outcome = await controller.share(origin: origin);
    if (!context.mounted) return;
    final message = switch (outcome) {
      ShareOutcome.missingFile => 'This photo no longer exists.'.tr,
      ShareOutcome.failed => 'The share sheet could not be opened.'.tr,
      ShareOutcome.shared ||
      ShareOutcome.dismissed ||
      ShareOutcome.opened => null,
    };
    if (message != null) _snack(context, message, isError: true);
  }

  Future<void> _delete(BuildContext context) async {
    final plan = controller.planDelete();
    final includeRelated = await confirmDelete(context, plan);
    if (includeRelated == null || !context.mounted) return;

    final result = await controller.delete(
      plan,
      includeRelated: includeRelated,
    );
    if (!context.mounted) return;

    if (result.isComplete) {
      // Close every stacked photo details screen, returning to the gallery
      // or project the photo was opened from.
      Get.until((route) => route.settings.name != AppRoutes.photoDetails);
      _snack(
        Get.context ?? context,
        result.deleted.where((n) => n.endsWith('.jpg')).length > 1
            ? 'Photos deleted'.tr
            : 'Photo deleted'.tr,
      );
    } else {
      _showFailures(context, result);
    }
  }

  void _showFailures(BuildContext context, DeleteResult result) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.error_outline_rounded, color: context.colors.error),
        title: Text('Some files were not deleted'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.deleted.isNotEmpty)
              Text(
                'Deleted: @files'.trParams({
                  'files': result.deleted.join(', '),
                }),
              ),
            const SizedBox(height: AppSpacing.sm),
            for (final failure in result.failures)
              Text(
                'Not deleted: @file (@reason)'.trParams({
                  'file': failure.fileName,
                  'reason': failure.message,
                }),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'.tr),
          ),
        ],
      ),
    );
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

class _Preview extends StatelessWidget {
  const _Preview({required this.photo});

  final GalleryPhoto photo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        return ColoredBox(
          color: AppColors.viewfinderBackground,
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Image.file(
                photo.file,
                key: ValueKey('${photo.path}:${photo.modifiedAt}'),
                fit: BoxFit.contain,
                cacheHeight: (constraints.maxHeight * dpr * 2).round(),
                semanticLabel: photo.isOriginal
                    ? 'Original photo'.tr
                    : 'Watermarked photo'.tr,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.onViewfinderMuted,
                  size: 48,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shows and changes the photo's project. A watermarked copy shows and
/// changes its original's project; it never gets its own assignment.
class _ProjectSection extends StatelessWidget {
  const _ProjectSection({required this.controller});

  final PhotoDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final project = controller.project;
      final photo = controller.photo;
      final canChange = controller.canChangeProject;

      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader('Project'.tr),
            Card(
              child: ListTile(
                leading: Icon(
                  project == null
                      ? Icons.folder_off_outlined
                      : Icons.folder_outlined,
                ),
                title: Text(project?.name ?? 'Not in a project'.tr),
                subtitle: photo.isWatermarked
                    ? Text(
                        canChange
                            ? 'Set through its original photo'.tr
                            : 'Original deleted; project can’t be changed'.tr,
                      )
                    : null,
                trailing: canChange
                    ? TextButton(
                        onPressed: controller.isBusy.value
                            ? null
                            : () => _choose(context, project),
                        child: Text(
                          project == null ? 'Add to project'.tr : 'Change'.tr,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _choose(BuildContext context, ProjectRef? current) async {
    final List<Project> projects;
    try {
      projects = await controller.assignableProjects();
    } catch (_) {
      if (context.mounted) {
        PhotoDetailsView._snack(
          context,
          'Projects could not be loaded.'.tr,
          isError: true,
        );
      }
      return;
    }
    if (!context.mounted) return;

    final choice = await showProjectPicker(
      context,
      projects: projects,
      selectedId: current?.id,
      title: controller.photo.isWatermarked
          ? 'Project for the original photo'.tr
          : 'Add to project'.tr,
      noneLabel: current == null ? 'No project'.tr : 'Remove from project'.tr,
    );
    if (choice == null || !context.mounted) return;

    final target = switch (choice) {
      ChoseProject(:final project) => project,
      ChoseNoProject() => null,
    };
    if (target?.id == current?.id) return;
    final error = await controller.setProject(target);
    if (!context.mounted) return;
    PhotoDetailsView._snack(
      context,
      error ??
          (target == null
              ? 'Removed from @name'.trParams({'name': current!.name})
              : 'Added to @name'.trParams({'name': target.name})),
      isError: error != null,
    );
  }
}

class _Related extends StatelessWidget {
  const _Related({required this.controller});

  final PhotoDetailsController controller;

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the gallery rescans, e.g. after a new watermark.
    return Obx(() => _build(context));
  }

  Widget _build(BuildContext context) {
    final photo = controller.photo;
    final items = photo.isOriginal ? controller.variants : [?controller.source];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          photo.isOriginal ? 'Watermarked versions'.tr : 'Original'.tr,
        ),
        if (items.isEmpty)
          Card(
            child: ListTile(
              leading: Icon(
                photo.isOriginal
                    ? Icons.branding_watermark_outlined
                    : Icons.link_off_rounded,
              ),
              title: Text(
                photo.isOriginal
                    ? 'No watermarked versions yet'.tr
                    : 'The original photo has been deleted'.tr,
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final (i, item) in items.indexed) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    onTap: () => controller.openRelated(item),
                    leading: ClipRRect(
                      borderRadius: AppRadius.smAll,
                      child: Image.file(
                        item.file,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        cacheWidth:
                            (48 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                    title: Text(
                      item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item.isWatermarked && item.record != null
                          ? '${item.record!.config.template.label.tr} · '
                                '${PhotoInfoFormatter.instant(item.record!.renderedAt)}'
                          : item.metadata == null
                          ? 'Original'.tr
                          : PhotoInfoFormatter.captureShort(item.metadata!),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// The photo's note, with an edit button on originals.
class _NoteSection extends StatelessWidget {
  const _NoteSection({required this.controller});

  final PhotoDetailsController controller;

  @override
  Widget build(BuildContext context) {
    final note = controller.note.value;
    if (note == null && !controller.canEditNote) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader('Note'.tr),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: Text(
                note ?? 'Add a note'.tr,
                style: note == null
                    ? context.text.bodyLarge?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      )
                    : null,
              ),
              subtitle: controller.canEditNote
                  ? null
                  : Text('Saved with this copy'.tr),
              trailing: controller.canEditNote
                  ? const Icon(Icons.edit_outlined)
                  : null,
              onTap: controller.canEditNote ? () => _edit(context) : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showNoteDialog(
      context,
      initial: controller.note.value,
      title: 'Photo note'.tr,
      helper:
          ('Shown in reports and on new watermarked copies. Copies already '
                  'made keep their old note.')
              .tr,
    );
    if (result == null || !context.mounted) return;
    final error = await controller.saveNote(result.isEmpty ? null : result);
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(error ?? 'Note saved'.tr),
        backgroundColor: error == null ? null : context.colors.error,
      ),
    );
  }
}
