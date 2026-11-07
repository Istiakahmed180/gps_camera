import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/features/gallery/models/gallery_filter.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';

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
              ButtonSegment(
                value: filter,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${filter.label} ${index.count(filter)}'),
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
      tooltip: 'Sort',
      icon: const Icon(Icons.sort_rounded),
      initialValue: selected,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final sort in GallerySort.values)
          CheckedPopupMenuItem(
            value: sort,
            checked: sort == selected,
            child: Text(sort.label),
          ),
      ],
    );
  }
}
