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
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: Obx(
        () =>
            controller.showArchived.value ||
                (controller.items.isEmpty &&
                    controller.query.value.trim().isEmpty)
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: controller.create,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New project'),
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
                    decoration: const InputDecoration(
                      hintText: 'Search projects',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: Obx(
                      () => SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: false, label: Text('Active')),
                          ButtonSegment(value: true, label: Text('Archived')),
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
          title: 'Projects could not be loaded',
          message: 'The project database could not be opened. Try again.',
          action: AppButton(
            label: 'Try again',
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
            ? 'No matching projects'
            : archived
            ? 'No archived projects'
            : 'No projects yet',
        message: searching
            ? 'Try a different name or description.'
            : archived
            ? 'Projects you archive appear here and can be restored.'
            : 'Create a project to group photos by site, client or job.',
        action: searching || archived
            ? null
            : AppButton(
                label: 'New project',
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
