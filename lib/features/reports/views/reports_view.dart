import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/gallery/utils/photo_info_formatter.dart';
import 'package:gps_camera/features/reports/controllers/reports_controller.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/reports/models/report_record.dart';
import 'package:gps_camera/features/reports/widgets/report_generation.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';
import 'package:gps_camera/shared/widgets/empty_state_view.dart';
import 'package:gps_camera/shared/widgets/responsive_center.dart';

enum _Action { open, share, delete }

class ReportsView extends GetView<ReportsController> {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reports'.tr)),
      body: Obx(() {
        switch (controller.status.value) {
          case ReportsStatus.loading:
            return const Center(child: CircularProgressIndicator());
          case ReportsStatus.error:
            return EmptyStateView(
              icon: Icons.error_outline_rounded,
              title: 'Reports could not be loaded'.tr,
              message: 'Try again.'.tr,
              action: AppButton(
                label: 'Try again'.tr,
                variant: AppButtonVariant.secondary,
                onPressed: controller.load,
              ),
            );
          case ReportsStatus.ready:
            break;
        }
        if (controller.reports.isEmpty) {
          return EmptyStateView(
            icon: Icons.picture_as_pdf_outlined,
            title: 'No reports yet'.tr,
            message:
                ('Create a PDF report from a project, or select photos in '
                        'the gallery and choose Create report.')
                    .tr,
          );
        }
        return ResponsiveCenter(
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView.separated(
              padding: AppSpacing.page,
              itemCount: controller.reports.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) =>
                  _ReportTile(report: controller.reports[i]),
            ),
          ),
        );
      }),
    );
  }
}

class _ReportTile extends GetView<ReportsController> {
  const _ReportTile({required this.report});

  final ReportFile report;

  @override
  Widget build(BuildContext context) {
    final record = report.record;
    final kind = switch (record?.type) {
      ReportType.project => 'Project · @name'.trParams({
        'name': record!.projectName ?? 'Unnamed'.tr,
      }),
      ReportType.selection => 'Selected photos'.tr,
      null => 'PDF report'.tr,
    };
    final details = [
      PhotoInfoFormatter.instant(report.generatedAt),
      if (record != null)
        '@n photo'.trPluralParams('@n photos', record.photoCount, {
          'n': '${record.photoCount}',
        }),
      PhotoInfoFormatter.fileSize(report.sizeBytes),
    ].join(' · ');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        leading: Icon(
          Icons.picture_as_pdf_outlined,
          color: context.colors.primary,
        ),
        title: Text(
          report.fileName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('$kind\n$details'),
        isThreeLine: true,
        onTap: () => openReport(context, controller.service, report.file),
        trailing: PopupMenuButton<_Action>(
          tooltip: 'Report actions'.tr,
          onSelected: (action) => _onAction(context, action),
          itemBuilder: (_) => [
            PopupMenuItem(value: _Action.open, child: Text('Open'.tr)),
            PopupMenuItem(value: _Action.share, child: Text('Share'.tr)),
            PopupMenuItem(value: _Action.delete, child: Text('Delete'.tr)),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, _Action action) async {
    switch (action) {
      case _Action.open:
        await openReport(context, controller.service, report.file);
      case _Action.share:
        await shareReport(context, controller.service, report.file);
      case _Action.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: context.colors.error,
            ),
            title: Text('Delete report?'.tr),
            content: Text(
              ('@file will be deleted. Photos, projects and '
                      'their data are not affected.')
                  .trParams({'file': report.fileName}),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'.tr),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.error,
                  foregroundColor: context.colors.onError,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Delete'.tr),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        final error = await controller.delete(report);
        if (!context.mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(error ?? 'Report deleted'.tr),
            backgroundColor: error == null ? null : context.colors.error,
          ),
        );
    }
  }
}
