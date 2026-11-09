import 'package:flutter/material.dart';
import 'package:gps_camera/app/theme/app_colors.dart';

/// The soft, gently raised look: surfaces lit from the top left, with a
/// light edge there and a shadow on the bottom right. Read with
/// `Theme.of(context).extension<SoftTheme>()` or `context.soft`.
@immutable
class SoftTheme extends ThemeExtension<SoftTheme> {
  const SoftTheme({
    required this.surface,
    required this.highlight,
    required this.shadow,
    required this.inset,
  });

  static const SoftTheme light = SoftTheme(
    surface: AppColors.lightSurface,
    highlight: AppColors.lightHighlight,
    shadow: AppColors.lightShadow,
    inset: AppColors.lightSurfaceContainer,
  );

  static const SoftTheme dark = SoftTheme(
    surface: AppColors.darkSurface,
    highlight: AppColors.darkHighlight,
    shadow: AppColors.darkShadow,
    inset: AppColors.darkSurfaceContainer,
  );

  /// Fill of raised surfaces.
  final Color surface;

  /// The lit edge (top left).
  final Color highlight;

  /// The shaded side (bottom right).
  final Color shadow;

  /// Fill of pressed-in areas such as text fields.
  final Color inset;

  /// The two shadows that make a surface look raised by [depth] pixels.
  List<BoxShadow> raised({double depth = 5}) => [
    BoxShadow(
      color: highlight.withValues(alpha: highlight.a * 0.9),
      offset: Offset(-depth * 0.8, -depth * 0.8),
      blurRadius: depth * 2.4,
    ),
    BoxShadow(
      color: shadow.withValues(alpha: shadow.a * 0.55),
      offset: Offset(depth, depth),
      blurRadius: depth * 2.8,
    ),
  ];

  /// A raised surface with rounded corners.
  BoxDecoration card({double radius = 20, double depth = 5, Color? color}) =>
      BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: raised(depth: depth),
      );

  /// The glossy brand fill of primary buttons.
  static const LinearGradient gloss = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.glossTop, AppColors.glossBottom],
  );

  @override
  SoftTheme copyWith({
    Color? surface,
    Color? highlight,
    Color? shadow,
    Color? inset,
  }) => SoftTheme(
    surface: surface ?? this.surface,
    highlight: highlight ?? this.highlight,
    shadow: shadow ?? this.shadow,
    inset: inset ?? this.inset,
  );

  @override
  SoftTheme lerp(SoftTheme? other, double t) {
    if (other == null) return this;
    return SoftTheme(
      surface: Color.lerp(surface, other.surface, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      inset: Color.lerp(inset, other.inset, t)!,
    );
  }
}

extension SoftThemeContext on BuildContext {
  SoftTheme get soft =>
      Theme.of(this).extension<SoftTheme>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? SoftTheme.dark
          : SoftTheme.light);
}
