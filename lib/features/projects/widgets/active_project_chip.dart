import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/projects/controllers/active_project_controller.dart';
import 'package:gps_camera/features/projects/models/project.dart';
import 'package:gps_camera/features/projects/widgets/project_picker_sheet.dart';

/// Camera-screen chip showing the project new photos go into.
class ActiveProjectChip extends StatelessWidget {
  const ActiveProjectChip({super.key, required this.controller});

  final ActiveProjectController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final project = controller.active.value;
      return Semantics(
        button: true,
        label: project == null
            ? 'No project selected. Choose a project for new photos'
            : 'New photos go to ${project.name}. Change project',
        excludeSemantics: true,
        child: Material(
          color: AppColors.viewfinderSurface,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _choose(context, project),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + AppSpacing.xxs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    project == null
                        ? Icons.folder_off_outlined
                        : Icons.folder_rounded,
                    size: AppSizes.iconSm,
                    color: project == null
                        ? AppColors.onViewfinderMuted
                        : AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      project?.name ?? 'No project',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge?.copyWith(
                        color: project == null
                            ? AppColors.onViewfinderMuted
                            : AppColors.onViewfinder,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: AppSizes.iconSm,
                    color: AppColors.onViewfinderMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _choose(BuildContext context, Project? current) async {
    List<Project> projects;
    try {
      projects = await controller.options();
    } catch (_) {
      projects = const [];
    }
    if (!context.mounted) return;
    final choice = await showProjectPicker(
      context,
      projects: projects,
      selectedId: current?.id,
      title: 'Project for new photos',
      noneLabel: 'No project',
    );
    if (choice == null) return;
    await controller.select(switch (choice) {
      ChoseProject(:final project) => project,
      ChoseNoProject() => null,
    });
  }
}
