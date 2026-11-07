import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/features/camera/controllers/capture_controller.dart';
import 'package:gps_camera/core/settings/app_preferences.dart';
import 'package:gps_camera/features/camera/widgets/camera_controls_bar.dart';
import 'package:gps_camera/features/camera/widgets/camera_top_bar.dart';
import 'package:gps_camera/features/camera/widgets/viewfinder_layer.dart';
import 'package:gps_camera/features/camera/widgets/camera_viewfinder.dart';
import 'package:gps_camera/features/camera/widgets/capture_toast.dart';
import 'package:gps_camera/features/camera/widgets/last_photo_thumbnail.dart';
import 'package:gps_camera/features/camera/widgets/shutter_button.dart';
import 'package:gps_camera/features/location/controllers/location_controller.dart';
import 'package:gps_camera/features/location/controllers/live_map_controller.dart';
import 'package:gps_camera/features/location/controllers/place_controller.dart';
import 'package:gps_camera/features/location/widgets/gps_status_panel.dart';
import 'package:gps_camera/features/watermark/services/watermark_settings_store.dart';
import 'package:gps_camera/features/watermark/widgets/live_watermark_overlay.dart';
import 'package:gps_camera/shared/widgets/note_dialog.dart';
import 'package:gps_camera/features/projects/controllers/active_project_controller.dart';
import 'package:gps_camera/features/projects/widgets/active_project_chip.dart';

class CameraView extends GetView<CaptureController> {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    final location = Get.find<LocationController>();
    final prefs = Get.find<AppPreferences>();

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
                      center: ActiveProjectChip(
                        controller: Get.find<ActiveProjectController>(),
                      ),
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
                                overlay: ViewfinderLayer(
                                  zoom: controller.zoom.value,
                                  onZoom: controller.setZoom,
                                  onFocus: controller.focusAt,
                                  focusPoint: controller.focusPoint.value,
                                  focusTaps: controller.focusTaps.value,
                                  showGrid: prefs.showGrid.value,
                                  countdown: controller.countdown.value,
                                  child: LiveWatermarkOverlay(
                                    location: location,
                                    place: Get.find<PlaceController>(),
                                    map: Get.find<LiveMapController>(),
                                    settings:
                                        Get.find<WatermarkSettingsStore>(),
                                  ),
                                ),
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
                      () => CameraControlsBar(
                        showGrid: prefs.showGrid.value,
                        timer: prefs.captureTimer.value,
                        zoom: controller.zoom.value,
                        zoomPresets: controller.zoomPresets,
                        enabled:
                            controller.canCapture &&
                            controller.countdown.value == null,
                        onToggleGrid: () =>
                            prefs.setShowGrid(!prefs.showGrid.value),
                        onCycleTimer: () => prefs.setCaptureTimer(
                          prefs.captureTimer.value.next,
                        ),
                        onZoom: controller.setZoom,
                        hasNote: prefs.captureNote.value != null,
                        onNote: () => _editNote(context, prefs),
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
                                isCountingDown:
                                    controller.countdown.value != null,
                                onPressed:
                                    controller.canCapture ||
                                        controller.countdown.value != null
                                    ? controller.shutter
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

  Future<void> _editNote(BuildContext context, AppPreferences prefs) async {
    final result = await showNoteDialog(
      context,
      title: 'Note for new photos',
      initial: prefs.captureNote.value,
      helper:
          'Added to every photo you take until you change or remove it. '
          'Shown on the watermark and in reports.',
    );
    if (result == null) return;
    await prefs.setCaptureNote(result);
  }
}
