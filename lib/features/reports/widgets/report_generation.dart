import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/routes/app_routes.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/reports/models/report_models.dart';
import 'package:gps_camera/features/reports/services/report_service.dart';

/// Generates [job] with a progress dialog, then offers Open / Share.
/// Returns the result, or null if generation failed (an error is shown).
Future<ReportResult?> generateReportWithProgress(
  BuildContext context,
  ReportService service,
  ReportJob job,
) async {
  if (service.isGenerating.value) {
    _snack(context, 'A report is already being generated.'.tr, isError: true);
    return null;
  }

  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final errorColor = context.colors.error;
  final generation = service.generate(job);
  // Shown until generation finishes; the user cannot dismiss it.
  _progressDialog(context, service, job.entries.length);

  try {
    final result = await generation;
    navigator.pop();
    if (context.mounted) await _showReady(context, service, result);
    return result;
  } on ReportException catch (e) {
    navigator.pop();
    messenger?.showSnackBar(
      SnackBar(content: Text(e.message), backgroundColor: errorColor),
    );
    return null;
  }
}

void _progressDialog(BuildContext context, ReportService service, int total) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text('Creating report'.tr),
        content: Obx(() {
          final p = service.progress.value;
          final text = p == null
              ? 'Preparing…'.tr
              : p.saving
              ? 'Saving PDF…'.tr
              : 'Adding photo @done of @total'.trParams({
                  'done': '${p.done}',
                  'total': '${p.total}',
                });
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: p == null || p.saving ? null : p.fraction,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(text, style: context.text.bodyMedium),
            ],
          );
        }),
      ),
    ),
  );
}

Future<void> _showReady(
  BuildContext context,
  ReportService service,
  ReportResult result,
) {
  final record = result.record;
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Report ready'.tr, style: sheet.text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${record.fileName}\n'
              '${'@n photo'.trPluralParams('@n photos', record.photoCount, {'n': '${record.photoCount}'})}'
              ' · ${'@n page'.trPluralParams('@n pages', record.pageCount, {'n': '${record.pageCount}'})}',
              style: sheet.text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => shareReport(sheet, service, result.file),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text('Share'.tr),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => openReport(sheet, service, result.file),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text('Open'.tr),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.of(sheet).pop();
                Get.toNamed<void>(AppRoutes.reports);
              },
              child: Text('All reports'.tr),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> shareReport(
  BuildContext context,
  ReportService service,
  File file,
) async {
  final outcome = await service.share(file);
  if (!context.mounted) return;
  final message = switch (outcome) {
    ShareOutcome.missingFile => 'This report no longer exists.'.tr,
    ShareOutcome.failed => 'The share sheet could not be opened.'.tr,
    _ => null,
  };
  if (message != null) _snack(context, message, isError: true);
}

Future<void> openReport(
  BuildContext context,
  ReportService service,
  File file,
) async {
  final outcome = await service.open(file);
  if (!context.mounted) return;
  final message = switch (outcome) {
    ReportOpenOutcome.opened => null,
    ReportOpenOutcome.noApp =>
      'No PDF viewer is installed. Use Share to send the report instead.'.tr,
    ReportOpenOutcome.missing => 'This report no longer exists.'.tr,
    ReportOpenOutcome.failed => 'The report could not be opened.'.tr,
  };
  if (message != null) _snack(context, message, isError: true);
}

SnackBar _errorBar(BuildContext context, String message) =>
    SnackBar(content: Text(message), backgroundColor: context.colors.error);

void _snack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    isError ? _errorBar(context, message) : SnackBar(content: Text(message)),
  );
}
