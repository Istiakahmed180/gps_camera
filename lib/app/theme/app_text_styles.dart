import 'package:flutter/material.dart';

abstract final class AppTextStyles {
  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) {
    return TextTheme(
      displaySmall: _style(36, 44, FontWeight.w600, -0.5, primary),
      headlineMedium: _style(28, 36, FontWeight.w600, -0.25, primary),
      headlineSmall: _style(24, 32, FontWeight.w600, 0, primary),
      titleLarge: _style(20, 28, FontWeight.w600, 0, primary),
      titleMedium: _style(16, 24, FontWeight.w600, 0.1, primary),
      titleSmall: _style(14, 20, FontWeight.w600, 0.1, primary),
      bodyLarge: _style(16, 24, FontWeight.w400, 0.15, primary),
      bodyMedium: _style(14, 20, FontWeight.w400, 0.15, primary),
      bodySmall: _style(12, 16, FontWeight.w400, 0.2, secondary),
      labelLarge: _style(14, 20, FontWeight.w600, 0.1, primary),
      labelMedium: _style(12, 16, FontWeight.w500, 0.4, primary),
      labelSmall: _style(11, 16, FontWeight.w500, 0.5, secondary),
    );
  }

  /// Fixed-width digits for coordinates, timestamps and counters.
  static const TextStyle tabularFigures = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextStyle _style(
    double size,
    double lineHeight,
    FontWeight weight,
    double letterSpacing,
    Color color,
  ) {
    return TextStyle(
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }
}
