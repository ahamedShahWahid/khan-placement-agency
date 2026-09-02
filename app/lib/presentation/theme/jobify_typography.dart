import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Jobify "Clear Sky" typography.
///
/// Display = Schibsted Grotesk w600 (calm, not heavy-black). Body/labels =
/// Inter. Data (score stamp, ₹, dates) = IBM Plex Mono via [mono]. All via
/// google_fonts — tests must use ThemeData.light(), never buildTheme().
///
/// Devanagari fallback: Inter, Schibsted Grotesk, and IBM Plex Mono are all
/// Latin/Cyrillic/Greek-subset families with no Devanagari glyphs in their
/// Google Fonts distribution. Hindi ARB strings rendered through either
/// [textTheme] (body/label copy) or [mono] (e.g. `_SpecRow` values on the
/// Profile screen, which render localized desired-role labels via
/// `desiredRoleLabel()`) would otherwise depend on undeclared platform/engine
/// fallback — reliable on Android (bundles Noto), inconsistent on iOS/web.
/// `_devanagariFallback` makes the fallback explicit and google_fonts-managed
/// everywhere, so Hindi text renders identically across platforms.
abstract final class JobifyTypography {
  static final List<String> _devanagariFallback = [
    GoogleFonts.notoSansDevanagari().fontFamily!,
  ];

  static TextTheme textTheme(Brightness brightness) {
    final base =
        brightness == Brightness.dark
            ? Typography.whiteMountainView
            : Typography.blackMountainView;
    return GoogleFonts.interTextTheme(base)
        .copyWith(
          displayLarge: GoogleFonts.schibstedGrotesk(
            fontSize: 34,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
          displayMedium: GoogleFonts.schibstedGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.18,
          ),
          headlineLarge: GoogleFonts.schibstedGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.22,
          ),
          headlineMedium: GoogleFonts.schibstedGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.28,
          ),
          titleLarge: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
          titleMedium: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.40,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.50,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.50,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.40,
          ),
          labelLarge: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.20,
          ),
          labelMedium: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.20,
          ),
          labelSmall: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.20,
          ),
        )
        .apply(fontFamilyFallback: _devanagariFallback);
  }

  /// The data / "shows its work" voice — IBM Plex Mono. Used for the score
  /// stamp, ₹ figures, timestamps — and, via `_SpecRow` on the Profile
  /// screen, localized values like the desired-role label, which can be
  /// Devanagari text under the `hi` locale. Pass the resolved color from the
  /// caller.
  static TextStyle mono({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
  }) => GoogleFonts.ibmPlexMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
  ).copyWith(fontFamilyFallback: _devanagariFallback);
}
