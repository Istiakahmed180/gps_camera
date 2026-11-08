import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gps_camera/app/i18n/count_text.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/core/services/share_service.dart';
import 'package:gps_camera/features/gallery/models/gallery_index.dart';
import 'package:gps_camera/features/projects/services/project_export_service.dart';

/// Asks what to include, builds the ZIP with progress, then opens the
/// share sheet.
Future<void> shareProjectZip(
  BuildContext context, {
  required String projectName,
  required GalleryIndex index,
}) async {
  final choice = await showDialog<(ProjectZipContents, bool)>(
    context: context,
    builder: (_) => _ChoiceDialog(index: index),
  );
  if (choice == null || !context.mounted) return;

  final service = Get.find<ProjectExportService>();
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final errorColor = context.colors.error;
  _progressDialog(context, service);
  ProjectZip zip;
  try {
    zip = await service.build(
      projectName: projectName,
      index: index,
      contents: choice.$1,
      includeCsv: choice.$2,
    );
  } on ProjectExportException catch (e) {
    navigator.pop();
    messenger?.showSnackBar(
      SnackBar(content: Text(e.message.tr), backgroundColor: errorColor),
    );
    return;
  }
  navigator.pop();

  final outcome = await Get.find<ShareService>().shareFile(
    zip.file,
    mimeType: 'application/zip',
  );
  final message = switch (outcome) {
    ShareOutcome.failed => 'The share sheet could not be opened.'.tr,
    ShareOutcome.missingFile => 'The ZIP could not be found.'.tr,
    _ => null,
  };
  if (message != null) {
    messenger?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: errorColor),
    );
  }
}

void _progressDialog(BuildContext context, ProjectExportService service) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text('Preparing ZIP'.tr),
        content: Obx(() {
          final p = service.progress.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: p == null || p.$2 == 0 ? null : p.$1 / p.$2,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                p == null
                    ? 'Preparing…'.tr
                    : 'Adding photo @done of @total'.trParams({
                        'done': '${p.$1}',
                        'total': '${p.$2}',
                      }),
                style: dialog.text.bodyMedium,
              ),
            ],
          );
        }),
      ),
    ),
  );
}

class _ChoiceDialog extends StatefulWidget {
  const _ChoiceDialog({required this.index});

  final GalleryIndex index;

  @override
  State<_ChoiceDialog> createState() => _ChoiceDialogState();
}

class _ChoiceDialogState extends State<_ChoiceDialog> {
  ProjectZipContents _contents = ProjectZipContents.watermarked;
  bool _csv = true;

  @override
  Widget build(BuildContext context) {
    final count = ProjectExportService.plan(widget.index, _contents).length;
    return AlertDialog(
      title: Text('Share photos as ZIP'.tr),
      contentPadding: const EdgeInsets.fromLTRB(0, AppSpacing.lg, 0, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<ProjectZipContents>(
              groupValue: _contents,
              onChanged: (v) {
                if (v != null) setState(() => _contents = v);
              },
              child: Column(
                children: [
                  for (final option in ProjectZipContents.values)
                    RadioListTile<ProjectZipContents>(
                      value: option,
                      title: Text(option.label.tr),
                      subtitle: Text(option.description.tr),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            CheckboxListTile(
              value: _csv,
              onChanged: (v) => setState(() => _csv = v ?? true),
              title: Text('Add a location spreadsheet'.tr),
              subtitle: Text(
                ('A CSV file with time, coordinates, address and note for '
                        'each photo. Opens in Excel or Google Sheets.')
                    .tr,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                0,
              ),
              child: Text(
                ('@n photo. Original photos get '
                        'their capture time and GPS location written in, so other '
                        'apps can read them.')
                    .trCount(
                      '@n photos. Original photos get '
                      'their capture time and GPS location written in, so other '
                      'apps can read them.',
                      count,
                      {'n': '$count'},
                    ),
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'.tr),
        ),
        FilledButton(
          onPressed: count == 0
              ? null
              : () => Navigator.of(context).pop((_contents, _csv)),
          child: Text('Create ZIP'.tr),
        ),
      ],
    );
  }
}
