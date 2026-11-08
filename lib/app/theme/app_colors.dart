import 'package:flutter/material.dart';

/// Raw color tokens. Widgets should read colors from [ColorScheme];
/// these tokens exist to build the schemes and for always-dark camera UI.
abstract final class AppColors {
  static const Color brand = Color(0xFF0B6E99);
  static const Color brandLight = Color(0xFF6CC0E5);
  static const Color accent = Color(0xFFF5A524);
  static const Color onAccent = Color(0xFF2A1B00);

  static const Color success = Color(0xFF2E9E6A);
  static const Color warning = Color(0xFFE0A100);

  /// The record button and recording badge.
  static const Color recording = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFC93C3C);
  static const Color errorDark = Color(0xFFFF8A80);

  static const Color lightBackground = Color(0xFFF6F7F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFEEF1F4);
  static const Color lightSurfaceContainerHigh = Color(0xFFE6EAEE);
  static const Color lightOutline = Color(0xFFB9C1CA);
  static const Color lightOutlineVariant = Color(0xFFDDE2E7);
  static const Color lightTextPrimary = Color(0xFF14181D);
  static const Color lightTextSecondary = Color(0xFF5B6470);

  static const Color darkBackground = Color(0xFF111418);
  static const Color darkSurface = Color(0xFF181C21);
  static const Color darkSurfaceContainer = Color(0xFF1F242A);
  static const Color darkSurfaceContainerHigh = Color(0xFF272D34);
  static const Color darkOutline = Color(0xFF4A535E);
  static const Color darkOutlineVariant = Color(0xFF2F363E);
  static const Color darkTextPrimary = Color(0xFFE8EBEF);
  static const Color darkTextSecondary = Color(0xFF9AA3AE);

  static const Color viewfinderBackground = Color(0xFF0D0F12);
  static const Color viewfinderSurface = Color(0xFF1A1E23);
  static const Color onViewfinder = Color(0xFFF2F4F7);
  static const Color onViewfinderMuted = Color(0xFF9AA3AE);
}
