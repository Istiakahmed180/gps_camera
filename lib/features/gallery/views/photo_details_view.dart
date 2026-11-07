import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/gallery/controllers/photo_details_controller.dart';
import 'package:gps_camera/features/gallery/models/gallery_photo.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/features/gallery/widgets/photo_action_menu.dart';
import 'package:gps_camera/features/gallery/widgets/photo_details_panel.dart';
import 'package:gps_camera/shared/widgets/section_header.dart';

class PhotoDetailsView extends GetView<PhotoDetailsController> {
  const PhotoDetailsView({super.key, required this.photo});

  final GalleryPhoto photo;

  @override
  String? get tag => photo.id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(photo.isOriginal ? 'Original' : 'Watermarked copy'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Delete',
              onPressed: controller.isBusy.value
                  ? null
                  : () => _delete(context),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= AppBreakpoints.medium;
          final preview = _Preview(photo: photo);
          final details = Obx(
            () => PhotoDetailsPanel(
              photo: photo,
              dimensions: controller.dimensions.value,
              related: _Related(controller: controller),
            ),
          );

          if (wide) {
            return Row(
              children: [
                Expanded(child: preview),
                SizedBox(
                  width: 420,
                  child: ListView(
                    padding: AppSpacing.page,
                    children: [details],
                  ),
                ),
              ],
            );
          }
          return ListView(
            children: [
              SizedBox(height: constraints.maxHeight * 0.55, child: preview),
              Padding(padding: AppSpacing.page, child: details),
            ],
          );
        },
      ),
      bottomNavigationBar: Obx(
        () => PhotoActionBar(
          isOriginal: photo.isOriginal,
          hasSource: controller.source != null,
          isBusy: controller.isBusy.value,
          onShare: () => _share(context),
          onWatermark: controller.openWatermarkEditor,
          onOpenOriginal: () {
            final source = controller.source;
            if (source != null) controller.openRelated(source);
          },
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final outcome = await controller.share(origin: origin);
    if (!context.mounted) return;
    final message = switch (outcome) {
      ShareOutcome.missingFile => 'This photo no longer exists.',
      ShareOutcome.failed => 'The share sheet could not be opened.',
      ShareOutcome.shared ||
      ShareOutcome.dismissed ||
      ShareOutcome.opened => null,
    };
    if (message != null) _snack(context, message, isError: true);
  }

  Future<void> _delete(BuildContext context) async {
    final plan = controller.planDelete();
    final includeRelated = await confirmDelete(context, plan);
    if (includeRelated == null || !context.mounted) return;

    final result = await controller.delete(
      plan,
      includeRelated: includeRelated,
    );
    if (!context.mounted) return;

    if (result.isComplete) {
      Get.until((route) => route.settings.name == AppRoutes.gallery);
      _snack(
        Get.context ?? context,
        result.deleted.where((n) => n.endsWith('.jpg')).length > 1
            ? 'Photos deleted'
            : 'Photo deleted',
      );
    } else {
      _showFailures(context, result);
    }
  }

  void _showFailures(BuildContext context, DeleteResult result) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.error_outline_rounded, color: context.colors.error),
        title: const Text('Some files were not deleted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.deleted.isNotEmpty)
              Text('Deleted: ${result.deleted.join(', ')}'),
            const SizedBox(height: AppSpacing.sm),
            for (final failure in result.failures)
              Text('Not deleted: ${failure.fileName} (${failure.message})'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void _snack(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? context.colors.error : null,
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.photo});

  final GalleryPhoto photo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        return ColoredBox(
          color: AppColors.viewfinderBackground,
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Image.file(
                photo.file,
                key: ValueKey('${photo.path}:${photo.modifiedAt}'),
                fit: BoxFit.contain,
                cacheHeight: (constraints.maxHeight * dpr * 2).round(),
                semanticLabel: photo.isOriginal
                    ? 'Original photo'
                    : 'Watermarked photo',
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.onViewfinderMuted,
                  size: 48,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Related extends StatelessWidget {
  const _Related({required this.controller});

  final PhotoDetailsController controller;

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the gallery rescans, e.g. after a new watermark.
    return Obx(() => _build(context));
  }

  Widget _build(BuildContext context) {
    final photo = controller.photo;
    final items = photo.isOriginal ? controller.variants : [?controller.source];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(photo.isOriginal ? 'Watermarked versions' : 'Original'),
        if (items.isEmpty)
          Card(
            child: ListTile(
              leading: Icon(
                photo.isOriginal
                    ? Icons.branding_watermark_outlined
                    : Icons.link_off_rounded,
              ),
              title: Text(
                photo.isOriginal
                    ? 'No watermarked versions yet'
                    : 'The original photo has been deleted',
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final (i, item) in items.indexed) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    onTap: () => controller.openRelated(item),
                    leading: ClipRRect(
                      borderRadius: AppRadius.smAll,
                      child: Image.file(
                        item.file,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        cacheWidth:
                            (48 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                    title: Text(
                      item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item.isWatermarked && item.record != null
                          ? '${item.record!.config.template.label} · '
                                '${PhotoInfoFormatter.instant(item.record!.renderedAt)}'
                          : item.metadata == null
                          ? 'Original'
                          : PhotoInfoFormatter.captureShort(item.metadata!),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
