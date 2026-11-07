import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/projects/models/project.dart';

/// What the user chose in the project picker.
sealed class ProjectChoice {
  const ProjectChoice();
}

class ChoseProject extends ProjectChoice {
  const ChoseProject(this.project);

  final Project project;
}

class ChoseNoProject extends ProjectChoice {
  const ChoseNoProject();
}

/// Lists active projects plus a "no project" option. Returns null when
/// dismissed, so callers can tell "cancel" from "no project".
Future<ProjectChoice?> showProjectPicker(
  BuildContext context, {
  required List<Project> projects,
  required String? selectedId,
  required String title,
  required String noneLabel,
}) {
  return showModalBottomSheet<ProjectChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Text(title, style: context.text.titleLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  _Option(
                    icon: Icons.folder_off_outlined,
                    label: noneLabel,
                    selected: selectedId == null,
                    onTap: () =>
                        Navigator.of(context).pop(const ChoseNoProject()),
                  ),
                  for (final project in projects)
                    _Option(
                      icon: Icons.folder_outlined,
                      label: project.name,
                      subtitle: project.description.isEmpty
                          ? null
                          : project.description,
                      selected: project.id == selectedId,
                      onTap: () =>
                          Navigator.of(context).pop(ChoseProject(project)),
                    ),
                  if (projects.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'No active projects yet. Create one in Projects.',
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      leading: Icon(icon, color: selected ? colors.primary : null),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: selected
          ? Icon(Icons.check_rounded, color: colors.primary)
          : null,
      selected: selected,
      onTap: onTap,
    );
  }
}
