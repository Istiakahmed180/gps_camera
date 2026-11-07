import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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
  });

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
            ? Center(child: CameraPreview(controller))
            : _buildMessage(),
      ),
    );
  }

  Widget _buildMessage() {
    return switch (status) {
      CameraStatus.initializing || CameraStatus.ready => const CameraMessage(
        title: 'Starting camera…',
        isLoading: true,
      ),
      CameraStatus.permissionDenied => CameraMessage(
        icon: Icons.no_photography_outlined,
        title: 'Camera access needed',
        message: 'Allow camera access to capture site photos.',
        action: AppButton(
          label: 'Allow camera',
          icon: Icons.photo_camera_outlined,
          onPressed: onRequestPermission,
        ),
      ),
      CameraStatus.permissionBlocked => CameraMessage(
        icon: Icons.no_photography_outlined,
        title: 'Camera access is turned off',
        message:
            'Enable the camera permission for GPS Camera in system '
            'settings, then return to the app.',
        action: AppButton(
          label: 'Open settings',
          icon: Icons.settings_outlined,
          onPressed: onOpenSettings,
        ),
      ),
      CameraStatus.error => CameraMessage(
        icon: Icons.videocam_off_outlined,
        title: 'Camera unavailable',
        message: errorMessage,
        action: AppButton(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
      ),
    };
  }
}
