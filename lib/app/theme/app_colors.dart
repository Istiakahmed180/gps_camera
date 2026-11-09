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

  static const Color lightBackground = Color(0xFFE9EEF5);
  static const Color lightSurface = Color(0xFFF1F5FA);
  static const Color lightSurfaceContainer = Color(0xFFE1E8F1);
  static const Color lightSurfaceContainerHigh = Color(0xFFD8E0EB);
  static const Color lightOutline = Color(0xFFB3BFCF);
  static const Color lightOutlineVariant = Color(0xFFD3DCE8);
  static const Color lightTextPrimary = Color(0xFF111A2B);
  static const Color lightTextSecondary = Color(0xFF56627A);

  static const Color darkBackground = Color(0xFF141A22);
  static const Color darkSurface = Color(0xFF1A212B);
  static const Color darkSurfaceContainer = Color(0xFF111720);
  static const Color darkSurfaceContainerHigh = Color(0xFF242C38);
  static const Color darkOutline = Color(0xFF4A535E);
  static const Color darkOutlineVariant = Color(0xFF2A3341);
  static const Color darkTextPrimary = Color(0xFFE8EBEF);
  static const Color darkTextSecondary = Color(0xFF9AA3AE);

  /// Soft (raised) look: a light edge on the top left and a shadow on the
  /// bottom right, as if lit from above.
  static const Color lightHighlight = Color(0xFFFFFFFF);
  static const Color lightShadow = Color(0xFFA9B8CE);
  static const Color darkHighlight = Color(0xFF252E3B);
  static const Color darkShadow = Color(0xFF080B10);

  /// Glossy primary buttons and the camera card: bright to deep brand blue.
  static const Color glossTop = Color(0xFF2FA3DB);
  static const Color glossBottom = Color(0xFF0A5F8A);

  static const Color viewfinderBackground = Color(0xFF0D0F12);
  static const Color viewfinderSurface = Color(0xFF1A1E23);
  static const Color onViewfinder = Color(0xFFF2F4F7);
  static const Color onViewfinderMuted = Color(0xFF9AA3AE);
}
