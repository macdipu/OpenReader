import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openreader/core/presentation/theme/color_schemes.dart';
import 'text_theme.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildTheme(isDark: false);
  static ThemeData get darkTheme => _buildTheme(isDark: true);

  static ThemeData _buildTheme({required bool isDark}) {
    Color c(AdaptiveColor ac) => isDark ? ac.dark : ac.light;
    final textTheme = isDark ? AppTextTheme.darkTextTheme : AppTextTheme.lightTextTheme;
    // Nocturne (dark/AMOLED) reads as hairline-bordered flat panels on true
    // black - no ambient drop shadows. OpenReader (light) uses soft shadows.
    final shadowAlpha = isDark ? 0.0 : 0.04;

    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: c(AppColors.primary),
      onPrimary: c(AppColors.onPrimary),
      primaryContainer: c(AppColors.primaryContainer),
      onPrimaryContainer: c(AppColors.onPrimaryContainer),
      secondary: c(AppColors.secondary),
      onSecondary: c(AppColors.onSecondary),
      secondaryContainer: c(AppColors.secondaryContainer),
      onSecondaryContainer: c(AppColors.onSecondaryContainer),
      tertiary: c(AppColors.tertiary),
      onTertiary: c(AppColors.onTertiary),
      tertiaryContainer: c(AppColors.tertiaryContainer),
      onTertiaryContainer: c(AppColors.onTertiaryContainer),
      error: c(AppColors.error),
      onError: c(AppColors.onError),
      errorContainer: c(AppColors.errorContainer),
      onErrorContainer: c(AppColors.onErrorContainer),
      surface: c(AppColors.surface),
      onSurface: c(AppColors.onSurface),
      onSurfaceVariant: c(AppColors.onSurfaceVariant),
      surfaceContainerLowest: c(AppColors.surfaceContainerLowest),
      surfaceContainerLow: c(AppColors.surfaceContainerLow),
      surfaceContainer: c(AppColors.surfaceContainer),
      surfaceContainerHigh: c(AppColors.surfaceContainerHigh),
      surfaceContainerHighest: c(AppColors.surfaceContainerHighest),
      outline: c(AppColors.outline),
      outlineVariant: c(AppColors.outlineVariant),
      shadow: c(AppColors.shadow),
      scrim: c(AppColors.scrim),
      inverseSurface: c(AppColors.inverseSurface),
      onInverseSurface: c(AppColors.onInverseSurface),
      inversePrimary: c(AppColors.inversePrimary),
      surfaceTint: c(AppColors.primary),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: c(AppColors.background),

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? c(AppColors.surfaceContainerLowest) : colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface),
        iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),

      cardTheme: CardThemeData(
        color: c(AppColors.surfaceContainerLowest),
        elevation: 0,
        shadowColor: colorScheme.shadow.withValues(alpha: shadowAlpha),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDark ? 8 : 12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.secondary,
          foregroundColor: colorScheme.onSecondary,
          elevation: 0,
          shadowColor: colorScheme.shadow.withValues(alpha: shadowAlpha),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: textTheme.labelLarge,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.secondary,
          foregroundColor: colorScheme.onSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.secondary,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c(AppColors.surfaceContainerLow),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: colorScheme.error),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSecondary,
        elevation: isDark ? 0 : 4,
        shape: const StadiumBorder(),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c(AppColors.surfaceContainerLow),
        selectedColor: colorScheme.primary,
        secondarySelectedColor: colorScheme.primary,
        deleteIconColor: colorScheme.onSurfaceVariant,
        labelStyle: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: colorScheme.onPrimary),
        side: BorderSide(color: colorScheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c(AppColors.surfaceContainerLowest),
        elevation: isDark ? 0 : 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDark ? BorderSide(color: colorScheme.outlineVariant) : BorderSide.none,
        ),
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c(AppColors.surfaceContainerLowest),
        elevation: isDark ? 0 : 8,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: isDark ? BorderSide(color: colorScheme.outlineVariant) : BorderSide.none,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      dividerTheme: DividerThemeData(color: c(AppColors.divider), thickness: 1, space: 1),

      iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        iconColor: colorScheme.onSurface,
        textColor: colorScheme.onSurface,
        titleTextStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? colorScheme.secondary : colorScheme.outline),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
            ? colorScheme.secondary.withValues(alpha: 0.5)
            : c(AppColors.surfaceContainerHighest)),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? colorScheme.secondary : Colors.transparent),
        side: BorderSide(color: colorScheme.outlineVariant),
        checkColor: WidgetStateProperty.all(colorScheme.onSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isDark ? 4 : 6)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? colorScheme.secondary : colorScheme.onSurfaceVariant),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.secondary,
        linearTrackColor: c(AppColors.surfaceContainerHigh),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c(AppColors.surfaceContainerLowest),
        selectedItemColor: colorScheme.secondary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: isDark ? 0 : 8,
        selectedLabelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelSmall,
      ),
    );
  }
}
