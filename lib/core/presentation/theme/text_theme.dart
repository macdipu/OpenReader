import 'package:flutter/material.dart';

/// Two type systems - see agentic/data/design/stitch/DESIGN_SPEC.md:
/// - Light (OpenReader): Inter throughout, JetBrains Mono for metadata.
/// - Dark (Nocturne/AMOLED): Space Grotesk headlines, Inter body,
///   JetBrains Mono labels/metadata.
///
/// All three families are bundled as local variable-font assets (see
/// pubspec.yaml `flutter.fonts`) rather than fetched via package:google_fonts
/// at runtime - OpenReader is offline-only (BRD: zero network calls).
class AppTextTheme {
  static const _inter = 'Inter';
  static const _spaceGrotesk = 'Space Grotesk';
  static const _jetBrainsMono = 'JetBrains Mono';

  static TextTheme get lightTextTheme => const TextTheme(
    // Display styles - largest text (no spec value given; Inter, kept as-is)
    displayLarge:
        TextStyle(fontFamily: _inter, fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25, height: 64 / 57),
    displayMedium: TextStyle(fontFamily: _inter, fontSize: 45, fontWeight: FontWeight.w400, height: 52 / 45),
    displaySmall: TextStyle(fontFamily: _inter, fontSize: 36, fontWeight: FontWeight.w400, height: 44 / 36),

    // Headline styles (DESIGN_SPEC headline-lg/md/sm, mobile sizes)
    headlineLarge:
        TextStyle(fontFamily: _inter, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.48, height: 30 / 24),
    headlineMedium:
        TextStyle(fontFamily: _inter, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3, height: 26 / 20),
    headlineSmall:
        TextStyle(fontFamily: _inter, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.16, height: 22 / 16),

    // Title styles
    titleLarge: TextStyle(fontFamily: _inter, fontSize: 22, fontWeight: FontWeight.w700, height: 28 / 22),
    titleMedium:
        TextStyle(fontFamily: _inter, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.15, height: 20 / 15),
    titleSmall:
        TextStyle(fontFamily: _inter, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 20 / 14),

    // Label styles (DESIGN_SPEC label-lg/md/sm)
    labelLarge:
        TextStyle(fontFamily: _inter, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.13, height: 18 / 13),
    labelMedium:
        TextStyle(fontFamily: _inter, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.44, height: 14 / 11),
    labelSmall:
        TextStyle(fontFamily: _inter, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, height: 12 / 10),

    // Body styles (DESIGN_SPEC body-lg/md/sm)
    bodyLarge: TextStyle(fontFamily: _inter, fontSize: 16, fontWeight: FontWeight.w400, height: 24 / 16),
    bodyMedium: TextStyle(fontFamily: _inter, fontSize: 14, fontWeight: FontWeight.w400, height: 20 / 14),
    bodySmall: TextStyle(fontFamily: _inter, fontSize: 12, fontWeight: FontWeight.w400, height: 16 / 12),
  );

  static TextTheme get darkTextTheme => const TextTheme(
    // Display - Space Grotesk (Nocturne headline font)
    displayLarge: TextStyle(
        fontFamily: _spaceGrotesk, fontSize: 56, fontWeight: FontWeight.w700, letterSpacing: -1.68, height: 64 / 56),
    displayMedium: TextStyle(fontFamily: _spaceGrotesk, fontSize: 45, fontWeight: FontWeight.w600, height: 52 / 45),
    displaySmall: TextStyle(fontFamily: _spaceGrotesk, fontSize: 36, fontWeight: FontWeight.w600, height: 44 / 36),

    // Headline - Space Grotesk, mobile sizes
    headlineLarge: TextStyle(
        fontFamily: _spaceGrotesk, fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.56, height: 36 / 28),
    headlineMedium: TextStyle(
        fontFamily: _spaceGrotesk, fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.36, height: 32 / 24),
    headlineSmall: TextStyle(fontFamily: _spaceGrotesk, fontSize: 20, fontWeight: FontWeight.w500, height: 28 / 20),

    // Title - Nocturne has no distinct title style; Inter body-derived
    titleLarge: TextStyle(fontFamily: _inter, fontSize: 22, fontWeight: FontWeight.w700, height: 28 / 22),
    titleMedium:
        TextStyle(fontFamily: _inter, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.18, height: 30 / 18),
    titleSmall: TextStyle(fontFamily: _inter, fontSize: 16, fontWeight: FontWeight.w600, height: 26.4 / 16),

    // Label - JetBrains Mono (label-lg has no dark override, stays Inter)
    labelLarge:
        TextStyle(fontFamily: _inter, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.13, height: 18 / 13),
    labelMedium: TextStyle(
        fontFamily: _jetBrainsMono, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.39, height: 20 / 13),
    labelSmall: TextStyle(
        fontFamily: _jetBrainsMono, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.55, height: 16 / 11),

    // Body - Inter
    bodyLarge:
        TextStyle(fontFamily: _inter, fontSize: 18, fontWeight: FontWeight.w400, letterSpacing: 0.18, height: 30 / 18),
    bodyMedium: TextStyle(fontFamily: _inter, fontSize: 16, fontWeight: FontWeight.w400, height: 26.4 / 16),
    bodySmall: TextStyle(fontFamily: _inter, fontSize: 14, fontWeight: FontWeight.w400, height: 22 / 14),
  );

  /// Monospace style for file sizes, hashes, pagination, timestamps
  /// (DESIGN_SPEC "mono-metadata" - JetBrains Mono in both themes).
  static const TextStyle monoMetadata =
      TextStyle(fontFamily: _jetBrainsMono, fontSize: 11, fontWeight: FontWeight.w500, height: 14 / 11);
}
