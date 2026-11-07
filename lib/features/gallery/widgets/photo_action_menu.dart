import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/features/gallery/services/gallery_service.dart';
import 'package:gps_camera/shared/widgets/app_button.dart';

/// Share plus the photo's main action: add a watermark to an original, or
/// open the original of a watermarked copy.
class PhotoActionBar extends StatelessWidget {
  const PhotoActionBar({
    super.key,
    required this.isOriginal,
    required this.hasSource,
    required this.isBusy,
    required this.onShare,
    required this.onWatermark,
    required this.onOpenOriginal,
  });

  final bool isOriginal;
  final bool hasSource;
  final bool isBusy;
  final VoidCallback onShare;
  final VoidCallback onWatermark;
  final VoidCallback onOpenOriginal;

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
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  variant: AppButtonVariant.secondary,
                  isExpanded: true,
                  onPressed: isBusy ? null : onShare,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: isOriginal
                    ? AppButton(
                        label: 'Add watermark',
                        icon: Icons.branding_watermark_outlined,
                        isExpanded: true,
                        onPressed: isBusy ? null : onWatermark,
                      )
                    : AppButton(
                        label: hasSource ? 'Open original' : 'Original deleted',
                        icon: Icons.photo_outlined,
                        isExpanded: true,
                        onPressed: isBusy || !hasSource ? null : onOpenOriginal,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks before deleting. For an original with watermarked copies, the user
/// chooses explicitly whether those copies go too (off by default).
/// Returns null when cancelled, otherwise whether to include related copies.
Future<bool?> confirmDelete(BuildContext context, DeletePlan plan) {
  final target = plan.target;
  return showDialog<bool>(
    context: context,
    builder: (context) {
      var includeRelated = false;
      return StatefulBuilder(
        builder: (context, setState) {
          final colors = context.colors;
          final count = plan.related.length;
          final copies = count == 1
              ? '1 watermarked copy'
              : '$count watermarked copies';

          final String message;
          if (target.isWatermarked) {
            message =
                'This watermarked copy will be permanently deleted. The '
                'original photo is not affected.';
          } else if (!plan.hasRelated) {
            message =
                'This photo and its location data will be permanently '
                'deleted.';
          } else {
            message = includeRelated
                ? 'This photo, its location data and $copies will be '
                      'permanently deleted.'
                : 'This photo and its location data will be permanently '
                      'deleted. Its $copies will be kept and shown as '
                      'having no original.';
          }

          return AlertDialog(
            icon: Icon(Icons.delete_outline_rounded, color: colors.error),
            title: Text(
              target.isWatermarked
                  ? 'Delete watermarked copy?'
                  : 'Delete photo?',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                if (plan.hasRelated) ...[
                  const SizedBox(height: AppSpacing.md),
                  CheckboxListTile(
                    value: includeRelated,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('Also delete $copies'),
                    onChanged: (v) =>
                        setState(() => includeRelated = v ?? false),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text('This can\'t be undone.', style: context.text.bodySmall),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
                onPressed: () => Navigator.of(context).pop(includeRelated),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );
    },
  );
}
