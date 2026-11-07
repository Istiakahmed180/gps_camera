import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/features/projects/controllers/projects_controller.dart';
import 'package:gps_camera/shared/widgets/empty_state_view.dart';

class ProjectsView extends GetView<ProjectsController> {
  const ProjectsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: const EmptyStateView(
        icon: Icons.folder_outlined,
        title: 'No projects yet',
        message: 'Group photos by site, client or job to build albums '
            'and reports.',
      ),
    );
  }
}
