import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/soft_theme.dart';

/// A gently raised panel (see [SoftTheme]); tappable when [onTap] is set.
class SoftSurface extends StatelessWidget {
  const SoftSurface({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 20,
    this.depth = 5,
    this.padding = EdgeInsets.zero,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final double depth;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final soft = context.soft;
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: soft.card(radius: radius, depth: depth, color: color),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}

/// A raised rounded square holding an icon, as on the welcome screen and
/// in empty states.
class SoftIconTile extends StatelessWidget {
  const SoftIconTile({
    super.key,
    required this.icon,
    this.size = 88,
    this.iconSize = 40,
    this.color,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  /// Icon colour; the brand blue by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: context.soft.card(radius: size * 0.3, depth: size / 14),
        child: Icon(
          icon,
          size: iconSize,
          color: color ?? (dark ? AppColors.brandLight : AppColors.glossBottom),
        ),
      ),
    );
  }
}

/// The glossy brand-blue button for the main action on a screen.
class GlossyButton extends StatelessWidget {
  const GlossyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.trailingArrow = false,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Replaces [icon], e.g. a progress spinner.
  final Widget? leading;

  /// Adds a round arrow on the end, as on "continue" buttons.
  final bool trailingArrow;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(height / 2.6);
    final text = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 16,
    );
    final lead =
        leading ?? (icon == null ? null : Icon(icon, color: Colors.white));

    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.45,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: SoftTheme.gloss,
            borderRadius: radius,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.glossTop.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Stack(
                children: [
                  // The shine across the top half.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: height / 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.28),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: height,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: trailingArrow ? 8 : 24,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (trailingArrow) SizedBox(width: height - 16),
                          if (lead != null) ...[
                            IconTheme.merge(
                              data: const IconThemeData(
                                color: Colors.white,
                                size: 20,
                              ),
                              child: lead,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              style: text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (trailingArrow) ...[
                            const SizedBox(width: 12),
                            Container(
                              width: height - 16,
                              height: height - 16,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ],
                      ),
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
}

/// Faint raised circles in the corners of a page, as decoration only.
class SoftBackdrop extends StatelessWidget {
  const SoftBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final soft = context.soft;
    Widget circle(double size) => IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              soft.highlight.withValues(alpha: 0.7),
              AppColors.glossTop.withValues(alpha: 0.14),
            ],
          ),
          boxShadow: soft.raised(depth: 8),
        ),
      ),
    );
    return Stack(
      children: [
        Positioned(top: -70, left: -80, child: circle(200)),
        Positioned(top: 140, right: -60, child: circle(120)),
        Positioned(bottom: -90, right: -70, child: circle(220)),
        Positioned.fill(child: child),
      ],
    );
  }
}
