import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GamerTheme {
  static const Color neonGreen = Color(0xFF00FFA7);
  static const Color neonPurple = Color(0xFF7C4DFF);
  static const Color bg = Color(0xFF0B0F1A);
  static const Color card = Color(0xFF111726);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: neonGreen,
        secondary: neonPurple,
        surface: card,
        background: bg,
      ),
      textTheme: GoogleFonts.orbitronTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: card.withOpacity(0.7),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
              color: neonGreen,
              width: 1,
              strokeAlign: BorderSide.strokeAlignOutside),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonGreen,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static BoxDecoration neonPanel() => BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x2200FFA7), Color(0x227C4DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: neonGreen.withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(color: Color(0x7700FFA7), blurRadius: 16, spreadRadius: -8),
          BoxShadow(
              color: Color(0x557C4DFF), blurRadius: 24, spreadRadius: -12),
        ],
      );
}
