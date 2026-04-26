import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Canvas
  static const canvas = Color(0xFFF5F1E8);
  static const canvasSubtle = Color(0xFFEFEADE);
  static const surface = Color(0xFFFBF7EE);
  static const surfaceSubtle = Color(0xFFEDE7D6);

  // Borders
  static const border = Color(0xFFC9C2B0);
  static const borderStrong = Color(0xFF8B8671);
  static const borderFaint = Color(0xFFDBD5C2);

  // Ink
  static const ink = Color(0xFF1C1C1A);
  static const inkMuted = Color(0xFF5D5B52);
  static const inkSubtle = Color(0xFF8B8671);

  // Accent — drafting blue
  static const accent = Color(0xFF1F4B8C);
  static const accentSoft = Color(0xFFE3ECF7);
  static const accentDark = Color(0xFF0F2A52);

  // Info — desaturated plum
  static const info = Color(0xFF5D4A7C);
  static const infoSoft = Color(0xFFE8E1F0);
  static const infoBorder = Color(0xFFB0A3CC);

  // Semantic
  static const risk = Color(0xFF8B2F1F);
  static const riskSoft = Color(0xFFF0DCD2);
  static const riskBorder = Color(0xFFC89580);

  static const warn = Color(0xFF8C6615);
  static const warnSoft = Color(0xFFF0E5CC);
  static const warnBorder = Color(0xFFC9AD73);

  static const ok = Color(0xFF3D5F3A);
  static const okSoft = Color(0xFFDEE5D6);
  static const okBorder = Color(0xFF8FAA89);

  static const gridLine = Color(0x1A1F4B8C);

  // Typography
  static TextStyle get displayLg => GoogleFonts.fraunces(fontSize: 36, fontWeight: FontWeight.w400, color: ink, height: 1.1, letterSpacing: -0.8);
  static TextStyle get displayMd => GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w400, color: ink, height: 1.15, letterSpacing: -0.5);
  static TextStyle get h1 => GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w500, color: ink, height: 1.2, letterSpacing: -0.4);
  static TextStyle get h2 => GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w600, color: ink, height: 1.3, letterSpacing: -0.1);
  static TextStyle get h3 => GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w600, color: ink, height: 1.4);
  static TextStyle get body => GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w400, color: ink, height: 1.5);
  static TextStyle get bodyMuted => GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w400, color: inkMuted, height: 1.5);
  static TextStyle get callout => GoogleFonts.ibmPlexMono(fontSize: 10, fontWeight: FontWeight.w500, color: inkMuted, height: 1.3, letterSpacing: 1.2);
  static TextStyle get caption => GoogleFonts.ibmPlexSans(fontSize: 11, fontWeight: FontWeight.w500, color: inkMuted, height: 1.4, letterSpacing: 0.2);
  static TextStyle get kpiNumber => GoogleFonts.fraunces(fontSize: 32, fontWeight: FontWeight.w400, color: ink, height: 1.0, letterSpacing: -1.0);
  static TextStyle get mono => GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w400, color: ink, height: 1.4);
  static TextStyle get monoSmall => GoogleFonts.ibmPlexMono(fontSize: 10.5, fontWeight: FontWeight.w500, color: inkMuted, height: 1.2, letterSpacing: 0.3);

  // Layout
  static const radiusSm = 2.0;
  static const radiusMd = 3.0;
  static const radiusLg = 4.0;
  static const gridStep = 24.0;

  static ThemeData get material {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: const ColorScheme.light(primary: accent, onPrimary: Colors.white, secondary: ink, surface: surface, onSurface: ink, error: risk),
      textTheme: GoogleFonts.ibmPlexSansTextTheme().apply(bodyColor: ink, displayColor: ink),
      dividerColor: border,
      splashColor: accentSoft,
      highlightColor: accentSoft,
      visualDensity: VisualDensity.compact,
    );
  }
}
