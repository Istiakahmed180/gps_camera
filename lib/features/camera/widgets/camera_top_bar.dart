import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/features/camera/widgets/camera_icon_button.dart';

class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    super.key,
    required this.flashMode,
    required this.showFlash,
    required this.showSwitch,
    required this.controlsEnabled,
    required this.onClose,
    required this.onFlash,
    required this.onSwitch,
  });

  final FlashMode flashMode;
  final bool showFlash;
  final bool showSwitch;
  final bool controlsEnabled;
  final VoidCallback onClose;
  final VoidCallback onFlash;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          CameraIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close camera',
            onPressed: onClose,
          ),
          const Spacer(),
          if (showFlash)
            CameraIconButton(
              icon: _flashIcon(flashMode),
              tooltip: 'Flash: ${_flashLabel(flashMode)}',
              onPressed: controlsEnabled ? onFlash : null,
            ),
          if (showFlash && showSwitch) const SizedBox(width: AppSpacing.sm),
          if (showSwitch)
            CameraIconButton(
              icon: Icons.cameraswitch_outlined,
              tooltip: 'Switch camera',
              onPressed: controlsEnabled ? onSwitch : null,
            ),
        ],
      ),
    );
  }

  static IconData _flashIcon(FlashMode mode) => switch (mode) {
    FlashMode.auto => Icons.flash_auto_rounded,
    FlashMode.always || FlashMode.torch => Icons.flash_on_rounded,
    FlashMode.off => Icons.flash_off_rounded,
  };

  static String _flashLabel(FlashMode mode) => switch (mode) {
    FlashMode.auto => 'Auto',
    FlashMode.always || FlashMode.torch => 'On',
    FlashMode.off => 'Off',
  };
}
