import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
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
      ),
      body: Obx(
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
      ),
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
                        onOpen: controller.openPhoto,
                      ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
