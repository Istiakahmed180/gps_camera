import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/features/projects/controllers/projects_controller.dart';
import 'package:gps_camera/features/projects/widgets/project_card.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';
import 'package:gps_camera/shared/widgets/empty_state_view.dart';
import 'package:gps_camera/shared/widgets/responsive_center.dart';

class ProjectsView extends GetView<ProjectsController> {
  const ProjectsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Projects'.tr)),
      floatingActionButton: Obx(
        () =>
            controller.showArchived.value ||
                (controller.items.isEmpty &&
                    controller.query.value.trim().isEmpty)
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: controller.create,
                icon: const Icon(Icons.add_rounded),
                label: Text('New project'.tr),
              ),
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => controller.query.value = v,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search projects'.tr,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: Obx(
                      () => SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: false, label: Text('Active'.tr)),
                          ButtonSegment(
                            value: true,
                            label: Text('Archived'.tr),
                          ),
                        ],
                        selected: {controller.showArchived.value},
                        onSelectionChanged: (s) =>
                            controller.showArchived.value = s.first,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: Obx(_list)),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    switch (controller.status.value) {
      case ProjectsStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ProjectsStatus.error:
        return EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'Projects could not be loaded'.tr,
          message: 'The project database could not be opened. Try again.'.tr,
          action: AppButton(
            label: 'Try again'.tr,
            variant: AppButtonVariant.secondary,
            onPressed: controller.load,
          ),
        );
      case ProjectsStatus.ready:
        break;
    }

    final items = controller.items;
    controller.rootPath.value;
    if (items.isEmpty) {
      final searching = controller.query.value.trim().isNotEmpty;
      final archived = controller.showArchived.value;
      return EmptyStateView(
        icon: archived ? Icons.inventory_2_outlined : Icons.folder_outlined,
        title: searching
            ? 'No matching projects'.tr
            : archived
            ? 'No archived projects'.tr
            : 'No projects yet'.tr,
        message: searching
            ? 'Try a different name or description.'.tr
            : archived
            ? 'Projects you archive appear here and can be restored.'.tr
            : 'Create a project to group photos by site, client or job.'.tr,
        action: searching || archived
            ? null
            : AppButton(
                label: 'New project'.tr,
                icon: Icons.add_rounded,
                onPressed: controller.create,
              ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          96,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) {
          final summary = items[i];
          return ProjectCard(
            summary: summary,
            coverPath: controller.coverPath(summary),
            onTap: () => controller.open(summary.project.id),
          );
        },
      ),
    );
  }
}
