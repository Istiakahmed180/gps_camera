import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gps_camera/app/theme/app_colors.dart';
import 'package:gps_camera/app/theme/app_dimens.dart';
import 'package:gps_camera/app/theme/app_text_styles.dart';
import 'package:gps_camera/app/theme/soft_theme.dart';

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
    final soft = isDark ? SoftTheme.dark : SoftTheme.light;
    const buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.lgAll);
    const pill = StadiumBorder();
    const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.xl);
    const buttonMinSize = Size(64, AppSizes.buttonHeight);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    // Text fields look pressed into the page: no outline until focused.
    const noBorder = OutlineInputBorder(
      borderRadius: AppRadius.lgAll,
      borderSide: BorderSide.none,
    );

    return ThemeData(
      colorScheme: scheme,
      extensions: [soft],
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
      // Cards float softly above the page instead of being outlined.
      cardTheme: CardThemeData(
        color: soft.surface,
        elevation: 3,
        shadowColor: soft.shadow.withValues(alpha: isDark ? 0.9 : 0.45),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark
              ? BorderSide(color: soft.highlight.withValues(alpha: 0.6))
              : BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          elevation: 3,
          shadowColor: scheme.primary.withValues(alpha: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          backgroundColor: soft.surface,
          side: BorderSide(color: scheme.outlineVariant),
          elevation: 2,
          shadowColor: soft.shadow.withValues(alpha: 0.5),
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
        fillColor: soft.inset,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + AppSpacing.xxs,
        ),
        border: noBorder,
        enabledBorder: noBorder,
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: soft.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: soft.shadow,
        height: 70,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.14),
        indicatorShape: pill,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: pill,
          backgroundColor: soft.inset,
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          side: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: pill,
        backgroundColor: soft.surface,
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.3 : 0.16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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
        backgroundColor: soft.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
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
