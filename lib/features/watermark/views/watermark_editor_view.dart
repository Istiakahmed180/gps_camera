import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/location/models/location_snapshot.dart';
import 'package:gps_camera/features/watermark/controllers/watermark_controller.dart';
import 'package:gps_camera/features/watermark/utils/capture_time_formatter.dart';
import 'package:gps_camera/features/watermark/widgets/watermark_preview.dart';
import 'package:gps_camera/features/watermark/widgets/watermark_settings_panel.dart';
import 'package:gps_camera/features/watermark/widgets/watermark_style_selector.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';
import 'package:gps_camera/shared/widgets/empty_state_view.dart';
import 'package:gps_camera/shared/widgets/section_header.dart';

class WatermarkEditorView extends GetView<WatermarkController> {
  const WatermarkEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Watermark')),
      body: Obx(
        () => switch (controller.status.value) {
          WatermarkEditorStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          WatermarkEditorStatus.error => EmptyStateView(
            icon: Icons.broken_image_outlined,
            title: 'Photo unavailable',
            message: controller.loadError.value ?? 'Something went wrong.',
            action: AppButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: controller.load,
            ),
          ),
          WatermarkEditorStatus.ready => const _Editor(),
        },
      ),
    );
  }
}

class _Editor extends GetView<WatermarkController> {
  const _Editor();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppBreakpoints.medium;
        final stage = _Stage(
          maxHeight: wide ? null : constraints.maxHeight * 0.42,
        );
        final controls = ListView(
          padding: AppSpacing.page,
          children: const [_LocationNote(), _Controls()],
        );

        return Column(
          children: [
            Expanded(
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: stage),
                        const VerticalDivider(width: 1),
                        SizedBox(width: 400, child: controls),
                      ],
                    )
                  : Column(
                      children: [
                        stage,
                        const Divider(height: 1),
                        Expanded(child: controls),
                      ],
                    ),
            ),
            const _SaveBar(),
          ],
        );
      },
    );
  }
}

class _Stage extends GetView<WatermarkController> {
  const _Stage({this.maxHeight});

  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final child = ColoredBox(
      color: watermarkStageColor,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Obx(() {
          final image = controller.preview.value;
          final content = controller.content;
          if (image == null || content == null) return const SizedBox.shrink();
          return WatermarkPreview(
            image: image,
            content: content,
            config: controller.config.value,
            mapImage: controller.mapImage.value,
          );
        }),
      ),
    );
    return maxHeight == null
        ? child
        : SizedBox(height: maxHeight, width: double.infinity, child: child);
  }
}

class _Controls extends GetView<WatermarkController> {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final config = controller.config.value;
      final content = controller.content;
      if (content == null) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Template'),
          WatermarkStyleSelector(
            selected: config.template,
            content: content,
            config: config,
            onSelected: (t) =>
                controller.updateConfig(config.copyWith(template: t)),
          ),
          const SizedBox(height: AppSpacing.xl),
          WatermarkSettingsPanel(
            config: config,
            hasAddress: controller.hasAddress,
            onChanged: controller.updateConfig,
          ),
        ],
      );
    });
  }
}

/// Explains what location this photo can show, before the user saves.
class _LocationNote extends GetView<WatermarkController> {
  const _LocationNote();

  @override
  Widget build(BuildContext context) {
    final location = controller.metadata.value?.location;
    final message = switch (location?.status) {
      LocationRecordStatus.unavailable =>
        'No location was recorded for this photo. The watermark will say '
            '"Location unavailable" instead of coordinates.',
      LocationRecordStatus.stale =>
        'This photo only has a last known location'
            '${location?.fixAge == null ? '' : ', from ${CaptureTimeFormatter.age(location!.fixAge!)} before capture'}. '
            'The watermark labels it that way.',
      _ => null,
    };
    if (message == null) return const SizedBox.shrink();

    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.tertiaryContainer,
          borderRadius: AppRadius.mdAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: colors.onTertiaryContainer,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends GetView<WatermarkController> {
  const _SaveBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          padding: AppSpacing.page,
          child: Obx(() {
            final result = controller.lastResult.value;
            final error = controller.saveError.value;
            final empty = controller.content?.isEmpty ?? false;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (result != null || error != null || empty) ...[
                  _StatusLine(
                    isError: error != null || empty,
                    message:
                        error ??
                        (empty
                            ? 'Choose at least one detail to show.'
                            : 'Saved as ${result!.output.uri.pathSegments.last}. '
                                  'The original is unchanged.'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppButton(
                  label: controller.isSaving.value
                      ? 'Saving…'
                      : 'Save watermarked copy',
                  icon: Icons.save_alt_rounded,
                  isExpanded: true,
                  isLoading: controller.isSaving.value,
                  onPressed: controller.canSave ? controller.save : null,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = isError ? colors.error : colors.primary;

    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            size: AppSizes.iconSm,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: context.text.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
