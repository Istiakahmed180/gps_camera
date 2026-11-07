import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/features/camera/controllers/capture_controller.dart';
import 'package:gps_camera/features/camera/widgets/camera_top_bar.dart';
import 'package:gps_camera/features/camera/widgets/camera_viewfinder.dart';
import 'package:gps_camera/features/camera/widgets/capture_toast.dart';
import 'package:gps_camera/features/camera/widgets/last_photo_thumbnail.dart';
import 'package:gps_camera/features/camera/widgets/shutter_button.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/location/widgets/gps_status_panel.dart';

class CameraView extends GetView<CaptureController> {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    final location = Get.find<LocationController>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.viewfinderBackground,
      ),
      child: Scaffold(
        backgroundColor: AppColors.viewfinderBackground,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.maxContentWidth,
              ),
              child: Column(
                children: [
                  Obx(
                    () => CameraTopBar(
                      flashMode: controller.flashMode.value,
                      showFlash: controller.isFlashSupported.value,
                      showSwitch: controller.canSwitchCamera.value,
                      controlsEnabled: controller.canCapture,
                      onClose: controller.close,
                      onFlash: controller.cycleFlashMode,
                      onSwitch: controller.switchCamera,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Obx(
                              () => CameraViewfinder(
                                status: controller.status.value,
                                camera: controller.camera.value,
                                errorMessage: controller.errorMessage.value,
                                onRequestPermission:
                                    controller.requestPermission,
                                onOpenSettings: controller.openSettings,
                                onRetry: controller.retry,
                              ),
                            ),
                          ),
                          Positioned(
                            left: AppSpacing.lg,
                            right: AppSpacing.lg,
                            bottom: AppSpacing.lg,
                            child: Center(
                              child: Obx(
                                () => CaptureToast(
                                  feedback: controller.feedback.value,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      0,
                    ),
                    child: Obx(
                      () => GpsStatusPanel(
                        status: location.status.value,
                        fix: location.fix.value,
                        isStale: location.isStale.value,
                        onRequestPermission: location.requestPermission,
                        onOpenAppSettings: location.openAppSettings,
                        onOpenLocationSettings: location.openLocationSettings,
                        onRetry: location.retry,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        Obx(
                          () => LastPhotoThumbnail(
                            path: controller.lastPhotoPath.value,
                            onTap: controller.openWatermarkEditor,
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Obx(
                              () => ShutterButton(
                                isCapturing: controller.isCapturing.value,
                                onPressed: controller.canCapture
                                    ? controller.capture
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: LastPhotoThumbnail.size),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
