import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
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
        // Back leaves selection mode first; nothing is changed.
        canPop: !controller.selecting.value,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.cancelSelection();
        },
        child: Scaffold(
          appBar: controller.selecting.value
              ? _selectionBar(context)
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
          tooltip: 'Create PDF report',
          onPressed: count == 0 ? null : () => _createReport(context),
          icon: const Icon(Icons.picture_as_pdf_outlined),
        ),
      ],
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
                                child: GalleryEmptyState(
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
