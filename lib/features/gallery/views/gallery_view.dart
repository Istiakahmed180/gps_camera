import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/features/gallery/controllers/gallery_controller.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';
import 'package:gps_camera/shared/widgets/empty_state_view.dart';

class GalleryView extends GetView<GalleryController> {
  const GalleryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery')),
      body: EmptyStateView(
        icon: Icons.photo_library_outlined,
        title: 'No photos yet',
        message:
            'Photos you capture will appear here with their location '
            'and timestamp.',
        action: AppButton(
          label: 'Open camera',
          icon: Icons.photo_camera_outlined,
          onPressed: controller.openCamera,
        ),
      ),
    );
  }
}
