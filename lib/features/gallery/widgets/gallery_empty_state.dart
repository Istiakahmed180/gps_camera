import 'package:flutter/material.dart';
import 'package:gps_camera/features/gallery/models/gallery_filter.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';
import 'package:gps_camera/shared/widgets/empty_state_view.dart';

class GalleryEmptyState extends StatelessWidget {
  const GalleryEmptyState({
    super.key,
    required this.filter,
    required this.onOpenCamera,
  });

  /// [GalleryFilter.all] means there are no photos at all.
  final GalleryFilter filter;
  final VoidCallback onOpenCamera;

  @override
  Widget build(BuildContext context) {
    return switch (filter) {
      GalleryFilter.all => EmptyStateView(
        icon: Icons.photo_library_outlined,
        title: 'No photos yet',
        message:
            'Photos you capture will appear here with their location '
            'and timestamp.',
        action: AppButton(
          label: 'Open camera',
          icon: Icons.photo_camera_outlined,
          onPressed: onOpenCamera,
        ),
      ),
      GalleryFilter.originals => const EmptyStateView(
        icon: Icons.photo_outlined,
        title: 'No originals',
        message: 'Original captures will appear here.',
      ),
      GalleryFilter.watermarked => const EmptyStateView(
        icon: Icons.branding_watermark_outlined,
        title: 'No watermarked photos',
        message:
            'Open an original and choose Add watermark to create a '
            'watermarked copy.',
      ),
    };
  }
}
