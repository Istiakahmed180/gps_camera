import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';

enum AppButtonVariant { primary, secondary, tertiary }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.isExpanded = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool isExpanded;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final callback = isLoading ? null : onPressed;
    final Widget? leading = isLoading
        ? const SizedBox.square(
            dimension: AppSizes.iconSm,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : (icon == null ? null : Icon(icon, size: AppSizes.iconSm));
    final child = Text(label);

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton.icon(
          onPressed: callback,
          icon: leading,
          label: child,
        ),
      AppButtonVariant.secondary => OutlinedButton.icon(
          onPressed: callback,
          icon: leading,
          label: child,
        ),
      AppButtonVariant.tertiary => TextButton.icon(
          onPressed: callback,
          icon: leading,
          label: child,
        ),
    };

    return isExpanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
