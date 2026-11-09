import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/features/camera/models/camera_status.dart';
import 'package:gps_camera/features/camera/widgets/camera_message.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';

class CameraViewfinder extends StatelessWidget {
  const CameraViewfinder({
    super.key,
    required this.status,
    required this.camera,
    required this.errorMessage,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onRetry,
    this.overlay,
  });

  /// Drawn over the live preview, sized exactly to it.
  final Widget? overlay;

  final CameraStatus status;
  final CameraController? camera;
  final String? errorMessage;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final controller = camera;
    final showPreview =
        status == CameraStatus.ready &&
        controller != null &&
        controller.value.isInitialized;

    return ClipRRect(
      borderRadius: AppRadius.lgAll,
      child: ColoredBox(
        color: AppColors.viewfinderSurface,
        child: showPreview
            ? Center(child: CameraPreview(controller, child: overlay))
            : _buildMessage(),
      ),
    );
  }

  Widget _buildMessage() {
    return switch (status) {
      CameraStatus.initializing || CameraStatus.ready => CameraMessage(
        title: 'Starting camera…'.tr,
        isLoading: true,
      ),
      CameraStatus.permissionDenied => CameraMessage(
        icon: Icons.no_photography_outlined,
        title: 'Camera access needed'.tr,
        message: 'Allow camera access to capture site photos.'.tr,
        action: AppButton(
          label: 'Allow camera'.tr,
          icon: Icons.photo_camera_outlined,
          onPressed: onRequestPermission,
        ),
      ),
      CameraStatus.permissionBlocked => CameraMessage(
        icon: Icons.no_photography_outlined,
        title: 'Camera access is turned off'.tr,
        message:
            ('Enable the camera permission for Locaproof in system '
                    'settings, then return to the app.')
                .tr,
        action: AppButton(
          label: 'Open settings'.tr,
          icon: Icons.settings_outlined,
          onPressed: onOpenSettings,
        ),
      ),
      CameraStatus.error => CameraMessage(
        icon: Icons.videocam_off_outlined,
        title: 'Camera unavailable'.tr,
        message: errorMessage,
        action: AppButton(
          label: 'Try again'.tr,
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
      ),
    };
  }
}
