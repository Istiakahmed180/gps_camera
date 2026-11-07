import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/features/camera/controllers/capture_controller.dart';
import 'package:gps_camera/features/camera/widgets/shutter_button.dart';
import 'package:gps_camera/features/camera/widgets/viewfinder_placeholder.dart';

class CameraView extends GetView<CaptureController> {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.viewfinderBackground,
      ),
      child: Scaffold(
        backgroundColor: AppColors.viewfinderBackground,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close camera',
                      onPressed: controller.close,
                      color: AppColors.onViewfinder,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: ViewfinderPlaceholder(),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: ShutterButton(onPressed: null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
