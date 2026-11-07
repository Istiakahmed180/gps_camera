import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/app/theme/app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(_lightScheme, AppColors.lightBackground);

  static ThemeData get dark => _build(_darkScheme, AppColors.darkBackground);

  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(seedColor: AppColors.brand).copyWith(
        primary: AppColors.brand,
        onPrimary: Colors.white,
        tertiary: AppColors.accent,
        onTertiary: AppColors.onAccent,
        error: AppColors.errorLight,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        onSurfaceVariant: AppColors.lightTextSecondary,
        surfaceContainerLowest: AppColors.lightSurface,
        surfaceContainerLow: AppColors.lightBackground,
        surfaceContainer: AppColors.lightSurfaceContainer,
        surfaceContainerHigh: AppColors.lightSurfaceContainerHigh,
        outline: AppColors.lightOutline,
        outlineVariant: AppColors.lightOutlineVariant,
      );

  static final ColorScheme _darkScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.brandLight,
        tertiary: AppColors.accent,
        onTertiary: AppColors.onAccent,
        error: AppColors.errorDark,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
        surfaceContainerLowest: AppColors.darkBackground,
        surfaceContainerLow: AppColors.darkSurface,
        surfaceContainer: AppColors.darkSurfaceContainer,
        surfaceContainerHigh: AppColors.darkSurfaceContainerHigh,
        outline: AppColors.darkOutline,
        outlineVariant: AppColors.darkOutlineVariant,
      );

  static ThemeData _build(ColorScheme scheme, Color background) {
    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = AppTextStyles.textTheme(
      primary: scheme.onSurface,
      secondary: scheme.onSurfaceVariant,
    );
    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.mdAll);
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.xl);
    const buttonMinSize = Size(64, AppSizes.buttonHeight);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle:
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: Colors.transparent),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + AppSpacing.xxs,
        ),
        border: inputBorder(scheme.outlineVariant),
        enabledBorder: inputBorder(scheme.outlineVariant),
        focusedBorder: inputBorder(scheme.primary, 1.5),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.5),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        iconColor: scheme.onSurfaceVariant,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
    );
  }
}
