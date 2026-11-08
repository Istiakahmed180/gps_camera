import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/core/extensions/context_extensions.dart';
import 'package:gps_camera/core/utils/script.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final latin = isLatinText(title);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        latin ? title.toUpperCase() : title,
        style: context.text.labelMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
          letterSpacing: latin ? 1.2 : 0,
          fontWeight: latin ? null : FontWeight.w600,
        ),
      ),
    );
  }
}
