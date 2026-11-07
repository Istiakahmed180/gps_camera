import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/reports/services/report_service.dart';
import 'package:gps_camera/features/reports/widgets/report_generation.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/features/gallery/models/gallery_filter.dart';
import 'package:gps_camera/features/gallery/widgets/gallery_empty_state.dart';
import 'package:gps_camera/features/gallery/widgets/gallery_filter_bar.dart';
import 'package:gps_camera/features/gallery/widgets/photo_grid.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';
import 'package:gps_camera/shared/widgets/empty_state_view.dart';
import 'package:gps_camera/shared/widgets/responsive_center.dart';

class GalleryView extends GetView<GalleryController> {
  const GalleryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopScope(
        // Back leaves selection or search first; nothing is changed.
        canPop: !controller.selecting.value && !controller.searching.value,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (controller.selecting.value) {
            controller.cancelSelection();
          } else {
            controller.stopSearch();
          }
        },
        child: Scaffold(
          appBar: controller.selecting.value
              ? _selectionBar(context)
              : controller.searching.value
              ? _searchBar()
              : _normalBar(),
          body: _body(),
        ),
      ),
    );
  }

  PreferredSizeWidget _selectionBar(BuildContext context) {
    final count = controller.selectedIds.length;
    return AppBar(
      leading: IconButton(
        tooltip: 'Cancel selection',
        onPressed: controller.cancelSelection,
        icon: const Icon(Icons.close_rounded),
      ),
      title: Text(count == 0 ? 'Select photos' : '$count selected'),
      actions: [
        IconButton(
          tooltip: 'Select all shown',
          onPressed: controller.selectAllVisible,
          icon: const Icon(Icons.select_all_rounded),
        ),
        IconButton(
          tooltip: 'Share',
          onPressed: count == 0 ? null : () => _shareSelected(context),
          icon: const Icon(Icons.ios_share_rounded),
        ),
        IconButton(
          tooltip: 'Create PDF report',
          onPressed: count == 0 ? null : () => _createReport(context),
          icon: const Icon(Icons.picture_as_pdf_outlined),
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: count == 0 || controller.isBusy.value
              ? null
              : () => _deleteSelected(context),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
  }

  PreferredSizeWidget _searchBar() {
    return AppBar(
      leading: IconButton(
        tooltip: 'Close search',
        onPressed: controller.stopSearch,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: TextField(
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Place, address, note or date',
          border: InputBorder.none,
        ),
        onChanged: controller.setQuery,
      ),
    );
  }

  Future<void> _shareSelected(BuildContext context) async {
    final files = [for (final p in controller.selectedPhotos) p.file];
    final outcome = await Get.find<ShareService>().shareImages(files);
    if (!context.mounted) return;
    final message = switch (outcome) {
      ShareOutcome.missingFile => 'These photos no longer exist.',
      ShareOutcome.failed => 'The share sheet could not be opened.',
      _ => null,
    };
    if (message != null) _snack(context, message, isError: true);
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final count = controller.selectedIds.length;
    final withCopies = controller.selectedWithCopies;
    var includeCopies = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setState) => AlertDialog(
          icon: Icon(Icons.delete_outline_rounded, color: dialog.colors.error),
          title: Text('Delete $count photo${count == 1 ? '' : 's'}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'They are removed from the app with their location data. '
                'Copies already in the phone gallery are not touched. This '
                'cannot be undone.',
              ),
              if (withCopies > 0)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: includeCopies,
                  onChanged: (v) => setState(() => includeCopies = v ?? true),
                  title: Text(
                    'Also delete watermarked copies of $withCopies '
                    'original${withCopies == 1 ? '' : 's'}',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dialog.colors.error,
                foregroundColor: dialog.colors.onError,
              ),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final results = await controller.deleteSelected(
      includeRelated: includeCopies,
    );
    if (!context.mounted) return;
    final removed = results.fold(0, (n, r) => n + r.removedPhotos.length);
    final failed = results.fold(0, (n, r) => n + r.failures.length);
    _snack(
      context,
      failed == 0
          ? 'Deleted $removed photo${removed == 1 ? '' : 's'}'
          : 'Deleted $removed, but $failed file'
                '${failed == 1 ? '' : 's'} could not be removed',
      isError: failed > 0,
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

  Future<void> _createReport(BuildContext context) async {
    final job = controller.selectionReport();
    if (job == null) return;
    final result = await generateReportWithProgress(
      context,
      Get.find<ReportService>(),
      job,
    );
    if (result != null) controller.cancelSelection();
  }

  PreferredSizeWidget _normalBar() {
    return AppBar(
      title: const Text('Gallery'),
      actions: [
        IconButton(
          tooltip: 'Search',
          onPressed: controller.startSearch,
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          tooltip: 'Map',
          onPressed: controller.openMap,
          icon: const Icon(Icons.map_outlined),
        ),
        IconButton(
          tooltip: 'Select photos for a report',
          onPressed: () => controller.startSelection(),
          icon: const Icon(Icons.checklist_rounded),
        ),
        Obx(
          () => GallerySortMenu(
            selected: controller.sort.value,
            onChanged: controller.setSort,
          ),
        ),
        IconButton(
          tooltip: 'Open camera',
          onPressed: controller.openCamera,
          icon: const Icon(Icons.photo_camera_outlined),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Obx(
          () => controller.isRefreshing.value
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
      ),
    );
  }

  Widget _body() {
    return Obx(
      () => switch (controller.status.value) {
        GalleryStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        GalleryStatus.error => EmptyStateView(
          icon: Icons.error_outline_rounded,
          title: 'Photos could not be loaded',
          message: 'Storage could not be read. Try again.',
          action: AppButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: controller.reload,
          ),
        ),
        GalleryStatus.ready => _Content(controller: controller),
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.controller});

  final GalleryController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final index = controller.index.value;
      if (index.isEmpty) {
        return GalleryEmptyState(
          filter: GalleryFilter.all,
          onOpenCamera: controller.openCamera,
        );
      }
      final photos = controller.visible;

      return ResponsiveCenter(
        maxWidth: 1200,
        child: Column(
          children: [
            GalleryFilterBar(
              selected: controller.filter.value,
              index: index,
              onChanged: controller.setFilter,
            ),
            if (controller.filterProjects.isNotEmpty)
              GalleryProjectFilter(
                selected: controller.projectFilter.value,
                projects: controller.filterProjects,
                onChanged: controller.setProjectFilter,
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.reload,
                child: photos.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height: constraints.maxHeight,
                                child: controller.query.value.trim().isNotEmpty
                                    ? const EmptyStateView(
                                        icon: Icons.search_off_rounded,
                                        title: 'No matching photos',
                                        message:
                                            'Try a place, part of the '
                                            'address, a note or a date '
                                            'like "07 Nov".',
                                      )
                                    : GalleryEmptyState(
                                        filter: controller.filter.value,
                                        onOpenCamera: controller.openCamera,
                                      ),
                              ),
                            ),
                      )
                    : PhotoGrid(
                        photos: photos,
                        index: index,
                        onOpen: controller.selecting.value
                            ? controller.toggleSelection
                            : controller.openPhoto,
                        onLongPress: (photo) => controller.selecting.value
                            ? controller.toggleSelection(photo)
                            : controller.startSelection(photo),
                        overlayBuilder: controller.selecting.value
                            ? (photo) => _SelectionMark(
                                selected: controller.selectedIds.contains(
                                  photo.id,
                                ),
                              )
                            : null,
                      ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (selected)
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.25),
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: colors.primary, width: 3),
            ),
          ),
        Positioned(
          right: AppSpacing.sm,
          bottom: AppSpacing.sm,
          child: Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? colors.primary : AppColors.onViewfinder,
          ),
        ),
      ],
    );
  }
}
