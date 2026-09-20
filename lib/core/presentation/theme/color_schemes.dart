import 'package:flutter/material.dart';

// =========================================================
// ADAPTIVE COLOR CLASS
// =========================================================

class AdaptiveColor {
  final Color light;
  final Color dark;

  const AdaptiveColor({required this.light, required this.dark});

  Color resolve(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? dark : light;
  }

  // Convenience method for cleaner syntax
  Color call(BuildContext context) => resolve(context);

  // Add opacity support
  AdaptiveColor withAlpha(double opacity) {
    return AdaptiveColor(
      light: light.withValues(alpha: opacity),
      dark: dark.withValues(alpha: opacity),
    );
  }
}

// =========================================================
// APP COLORS - ORGANIZED & MAINTAINABLE
// =========================================================

class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // =========================================================
  // BRAND COLORS
  // OpenReader (light) / Nocturne Reader (dark, AMOLED true-black)
  // See agentic/data/design/stitch/DESIGN_SPEC.md
  // =========================================================

  static const Color brandPrimary = Color(0xFF0051D5);
  static const Color brandSecondary = Color(0xFF38BDF8);
  static const Color brandAccent = Color(0xFF059669);
  static const Color brandGreen = Color(0xFF10B981);
  static const Color brandGray = Color(0xFFE2E8F0);

  // =========================================================
  // MATERIAL 3 SYSTEM COLORS - ADAPTIVE
  // =========================================================

  // Primary - near-black ink (light) / soft sky text-on-black (dark)
  static const primary = AdaptiveColor(
    light: Color(0xFF091426),
    dark: Color(0xFF8ED5FF),
  );

  static const onPrimary = AdaptiveColor(
    light: Colors.white,
    dark: Color(0xFF00354A),
  );

  static const primaryContainer = AdaptiveColor(
    light: Color(0xFF1E293B),
    dark: Color(0xFF38BDF8),
  );

  static const onPrimaryContainer = AdaptiveColor(
    light: Colors.white,
    dark: Color(0xFF00354A),
  );

  // Secondary - the real interactive/CTA accent (buttons, active states,
  // focus rings, progress fill). Nocturne has no separate accent, so dark
  // reuses primary-container's electric sky blue.
  static const secondary = AdaptiveColor(
    light: Color(0xFF0051D5),
    dark: Color(0xFF38BDF8),
  );

  static const onSecondary = AdaptiveColor(
    light: Colors.white,
    dark: Color(0xFF00354A),
  );

  static const secondaryContainer = AdaptiveColor(
    light: Color(0xFFDCE9FF),
    dark: Color(0xFF0F2A3D),
  );

  static const onSecondaryContainer = AdaptiveColor(
    light: Color(0xFF00266B),
    dark: Color(0xFF8ED5FF),
  );

  // Tertiary - success/mint accent (also the XLSX format accent family)
  static const tertiary = AdaptiveColor(
    light: Color(0xFF059669),
    dark: Color(0xFF4EE6AA),
  );

  static const onTertiary = AdaptiveColor(
    light: Colors.white,
    dark: Color(0xFF003825),
  );

  static const tertiaryContainer = AdaptiveColor(
    light: Color(0xFFECFDF5),
    dark: Color(0xFF22C990),
  );

  static const onTertiaryContainer = AdaptiveColor(
    light: Color(0xFF00301F),
    dark: Color(0xFF003825),
  );

  // Error
  static const error = AdaptiveColor(
    light: Color(0xFFBA1A1A),
    dark: Color(0xFFFFB4AB),
  );

  static const onError = AdaptiveColor(
    light: Colors.white,
    dark: Color(0xFF690005),
  );

  static const errorContainer = AdaptiveColor(
    light: Color(0xFFFFDAD6),
    dark: Color(0xFF93000A),
  );

  static const onErrorContainer = AdaptiveColor(
    light: Color(0xFF410002),
    dark: Color(0xFFFFDAD6),
  );

  // Surface
  static const surface = AdaptiveColor(
    light: Color(0xFFF8FAFC),
    dark: Color(0xFF000000),
  );

  static const onSurface = AdaptiveColor(
    light: Color(0xFF0F172A),
    dark: Color(0xFFF1F5F9),
  );

  static const onSurfaceVariant = AdaptiveColor(
    light: Color(0xFF475569),
    dark: Color(0xFF94A3B8),
  );

  // Layered surface tiers - low to high emphasis, for card/dialog/sheet
  // hierarchy. Dark stays true-black at the lowest tier (AMOLED) and steps
  // up through Nocturne's "deep-space elevation" panels.
  static const surfaceContainerLowest = AdaptiveColor(
    light: Color(0xFFFFFFFF),
    dark: Color(0xFF0A0E17),
  );

  static const surfaceContainerLow = AdaptiveColor(
    light: Color(0xFFF1F5F9),
    dark: Color(0xFF181B25),
  );

  static const surfaceContainer = AdaptiveColor(
    light: Color(0xFFEAF1FF),
    dark: Color(0xFF1C1F29),
  );

  static const surfaceContainerHigh = AdaptiveColor(
    light: Color(0xFFDCE9FF),
    dark: Color(0xFF262A34),
  );

  static const surfaceContainerHighest = AdaptiveColor(
    light: Color(0xFFCBD5E1),
    dark: Color(0xFF31353F),
  );

  // Background - alias target for scaffolds; AMOLED true-black on dark.
  static const background = AdaptiveColor(
    light: Color(0xFFF8FAFC),
    dark: Color(0xFF000000),
  );

  static const onBackground = AdaptiveColor(
    light: Color(0xFF0F172A),
    dark: Color(0xFFF1F5F9),
  );

  // Outlines
  static const outline = AdaptiveColor(
    light: Color(0xFFCBD5E1),
    dark: Color(0xFF334155),
  );

  static const outlineVariant = AdaptiveColor(
    light: Color(0xFFE2E8F0),
    dark: Color(0xFF1E293B),
  );

  // Shadow & Scrim
  static const shadow = AdaptiveColor(
    light: Colors.black,
    dark: Colors.black,
  );

  static const scrim = AdaptiveColor(
    light: Colors.black,
    dark: Colors.black,
  );

  // Inverse
  static const inverseSurface = AdaptiveColor(
    light: Color(0xFF213145),
    dark: Color(0xFFDFE2EF),
  );

  static const onInverseSurface = AdaptiveColor(
    light: Color(0xFFEAF1FF),
    dark: Color(0xFF0F131C),
  );

  static const inversePrimary = AdaptiveColor(
    light: Color(0xFF8ED5FF),
    dark: Color(0xFF091426),
  );

  // =========================================================
  // SEMANTIC COLORS - ADAPTIVE
  // =========================================================

  static const success = AdaptiveColor(
    light: Color(0xFF059669),
    dark: Color(0xFF4EE6AA),
  );

  static const onSuccess = AdaptiveColor(
    light: Colors.white,
    dark: Color(0xFF003825),
  );

  static const successContainer = AdaptiveColor(
    light: Color(0xFFECFDF5),
    dark: Color(0xFF12472C),
  );

  static const onSuccessContainer = AdaptiveColor(
    light: Color(0xFF00301F),
    dark: Color(0xFFECFDF5),
  );

  static const warning = AdaptiveColor(
    light: Color(0xFFD97706),
    dark: Color(0xFFFB923C),
  );

  static const onWarning = AdaptiveColor(
    light: Colors.white,
    dark: Color(0xFF3A1D00),
  );

  static const warningContainer = AdaptiveColor(
    light: Color(0xFFFFFBEB),
    dark: Color(0xFF4A3200),
  );

  static const onWarningContainer = AdaptiveColor(
    light: Color(0xFF3D2E00),
    dark: Color(0xFFFFFBEB),
  );

  static const info = AdaptiveColor(
    light: Color(0xFF2563EB),
    dark: Color(0xFF38BDF8),
  );

  static const onInfo = AdaptiveColor(
    light: Colors.white,
    dark: Color(0xFF00354A),
  );

  static const infoContainer = AdaptiveColor(
    light: Color(0xFFEFF6FF),
    dark: Color(0xFF0F2A3D),
  );

  static const onInfoContainer = AdaptiveColor(
    light: Color(0xFF0A2E5C),
    dark: Color(0xFFEFF6FF),
  );

  // =========================================================
  // COMMON UI COLORS - ADAPTIVE
  // =========================================================

  static const red = AdaptiveColor(
    light: Color(0xFFEF4444),
    dark: Color(0xFFF87171),
  );

  static const orange = AdaptiveColor(
    light: Color(0xFFF97316),
    dark: Color(0xFFFB923C),
  );

  static const yellow = AdaptiveColor(
    light: Color(0xFFEAB308),
    dark: Color(0xFFFACC15),
  );

  static const green = AdaptiveColor(
    light: Color(0xFF22C55E),
    dark: Color(0xFF4ADE80),
  );

  static const blue = AdaptiveColor(
    light: Color(0xFF3B82F6),
    dark: Color(0xFF60A5FA),
  );

  static const purple = AdaptiveColor(
    light: Color(0xFF9333EA),
    dark: Color(0xFFA78BFA),
  );

  static const pink = AdaptiveColor(
    light: Color(0xFFEC4899),
    dark: Color(0xFFF472B6),
  );

  static const cyan = AdaptiveColor(
    light: Color(0xFF06B6D4),
    dark: Color(0xFF22D3EE),
  );

  static const indigo = AdaptiveColor(
    light: Color(0xFF6366F1),
    dark: Color(0xFF818CF8),
  );

  static const emerald = AdaptiveColor(
    light: Color(0xFF10B981),
    dark: Color(0xFF34D399),
  );

  // =========================================================
  // TEXT COLORS - ADAPTIVE
  // =========================================================

  static const text = AdaptiveColor(
    light: Color(0xFF0F172A),
    dark: Color(0xFFF1F5F9),
  );

  static const textSecondary = AdaptiveColor(
    light: Color(0xFF475569),
    dark: Color(0xFF94A3B8),
  );

  static const textTertiary = AdaptiveColor(
    light: Color(0xFF94A3B8),
    dark: Color(0xFF64748B),
  );

  static const textDisabled = AdaptiveColor(
    light: Color(0xFFCBD5E1),
    dark: Color(0xFF334155),
  );

  // =========================================================
  // BORDER & DIVIDER COLORS - ADAPTIVE
  // =========================================================

  static const border = AdaptiveColor(
    light: Color(0xFFE2E8F0),
    dark: Color(0xFF1E293B),
  );

  static const divider = AdaptiveColor(
    light: Color(0xFFE2E8F0),
    dark: Color(0xFF1E293B),
  );

  // =========================================================
  // SPECIAL PURPOSE COLORS
  // =========================================================

  // Complaint/Report specific colors
  static const complaint = AdaptiveColor(
    light: Color(0xFFBA1A1A),
    dark: Color(0xFFFFB4AB),
  );

  static const complaintBackground = AdaptiveColor(
    light: Color(0xFFFFDAD6),
    dark: Color(0xFF2D1517),
  );

  // Hero gradients
  static const heroGradientStart = AdaptiveColor(
    light: Color(0xFF091426),
    dark: Color(0xFF000000),
  );

  static const heroGradientEnd = AdaptiveColor(
    light: Color(0xFF1E293B),
    dark: Color(0xFF0A0E17),
  );

  // =========================================================
  // STATIC GRADIENT COLORS (for complex gradients)
  // =========================================================

  static const Color cyan50 = Color(0xFFECFEFF);
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color cyan500 = Color(0xFF06B6D4);
  static const Color cyan600 = Color(0xFF0891B2);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald600 = Color(0xFF059669);
  static const Color green500 = Color(0xFF22C55E);
  static const Color green600 = Color(0xFF16A34A);
  static const Color purple500 = Color(0xFF9333EA);
  static const Color purple600 = Color(0xFF7C3AED);
  static const Color pink500 = Color(0xFFEC4899);
  static const Color pink600 = Color(0xFFDB2777);

  // With alpha
  static const Color cyan500Alpha30 = Color(0x4D06B6D4);
  static const Color blue600Alpha30 = Color(0x4D2563EB);
  static const Color purple500Alpha30 = Color(0x4D9333EA);
  static const Color pink500Alpha30 = Color(0x4DEC4899);
  static const Color complaint50 = Color(0xFFFFEEF0);
  static const Color complaint500 = Color(0xFFEF4444);
  static const Color complaint600 = Color(0xFFDC2626);
  static const Color complaint500Alpha20 = Color(0x33EF4444);
  static const Color complaint500Alpha30 = Color(0x4DEF4444);
  static const Color darkHeroStart = Color(0xFF051029);
  static const Color darkHeroEnd = Color(0xFF0F1B3A);

  // Additional static colors for themes
  static const Color lightTertiaryContainer = Color(0xFFFFE7DF);
  static const Color darkTertiaryContainer = Color(0xFF661F0F);
  static const Color darkErrorContainer = Color(0xFF8C1D18);
  static const Color darkSurface = Color(0xFF0F131A);
  static const Color darkBackground = Color(0xFF050A14);
  static const Color indigo500 = Color(0xFF6366F1);
}
