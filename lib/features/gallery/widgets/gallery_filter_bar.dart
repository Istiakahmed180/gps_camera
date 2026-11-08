import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/features/gallery/models/gallery_filter.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/projects/models/project.dart';

class GalleryFilterBar extends StatelessWidget {
  const GalleryFilterBar({
    super.key,
    required this.selected,
    required this.index,
    required this.onChanged,
  });

  final GalleryFilter selected;
  final GalleryIndex index;
  final ValueChanged<GalleryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<GalleryFilter>(
          showSelectedIcon: false,
          segments: [
            for (final filter in GalleryFilter.values)
              // The video filter appears once there are videos.
              if (filter != GalleryFilter.videos ||
                  selected == GalleryFilter.videos ||
                  index.count(filter) > 0)
                ButtonSegment(
                  value: filter,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('${filter.label.tr} ${index.count(filter)}'),
                  ),
                ),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    );
  }
}

class GallerySortMenu extends StatelessWidget {
  const GallerySortMenu({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final GallerySort selected;
  final ValueChanged<GallerySort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<GallerySort>(
      tooltip: 'Sort'.tr,
      icon: const Icon(Icons.sort_rounded),
      initialValue: selected,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final sort in GallerySort.values)
          CheckedPopupMenuItem(
            value: sort,
            checked: sort == selected,
            child: Text(sort.label.tr),
          ),
      ],
    );
  }
}

/// Chip that narrows the gallery to one project or to photos without one.
class GalleryProjectFilter extends StatelessWidget {
  const GalleryProjectFilter({
    super.key,
    required this.selected,
    required this.projects,
    required this.onChanged,
  });

  final ProjectFilter selected;
  final List<ProjectRef> projects;
  final ValueChanged<ProjectFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = selected.unassigned
        ? 'No project'.tr
        : selected.projectId == null
        ? 'All projects'.tr
        : projects
                  .where((p) => p.id == selected.projectId)
                  .map((p) => p.name)
                  .firstOrNull ??
              'All projects'.tr;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: PopupMenuButton<ProjectFilter>(
          tooltip: 'Filter by project'.tr,
          onSelected: onChanged,
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: ProjectFilter.any,
              checked: selected == ProjectFilter.any,
              child: Text('All projects'.tr),
            ),
            CheckedPopupMenuItem(
              value: ProjectFilter.none,
              checked: selected == ProjectFilter.none,
              child: Text('No project'.tr),
            ),
            if (projects.isNotEmpty) const PopupMenuDivider(),
            for (final project in projects)
              CheckedPopupMenuItem(
                value: ProjectFilter.project(project.id),
                checked: selected.projectId == project.id,
                child: Text(project.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          child: IgnorePointer(
            child: FilterChip(
              avatar: const Icon(Icons.folder_outlined, size: 18),
              label: Text('$label  ▾'),
              selected: selected.isActive,
              showCheckmark: false,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
  }
}
