import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hive Sense palette, sampled from the onboarding reference image:
/// warm cream background, honey-gold primary, near-black ink.
class AppColors {
  // Background
  static const Color bgPrimary = Color(0xFFFFF8EA); // cream
  static const Color bgSecondary = Color(0xFFFFFFFF); // card white
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgElevated = Color(0xFFF4EDD9);
  static const Color border = Color(0xFFE4DCC8);

  // Accents
  static const Color accent = Color(0xFFD8A93D); // honey-gold
  static const Color accent2 = Color(0xFFB25A3C); // terracotta
  static const Color accent3 = Color(0xFF5F7F5A); // leaf green
  static const Color darkGreen = Color(0xFF2C5E43); // forest/apiary green
  static const Color lightGreenCard = Color(0xFFEAF2EC); // soft green badge fill
  static const Color blue = Color(0xFF3A4A63);
  static const Color purple = Color(0xFF6B5B3E);

  // Text
  static const Color textPrimary = Color(0xFF211D16);
  static const Color textSecondary = Color(0xFF8B8378);
  static const Color textMuted = Color(0xFFD8D0BF);

  // Status colors
  static const Color success = Color(0xFF4C8C4A);
  static const Color warning = Color(0xFFC98A1B);
  static const Color error = Color(0xFFB44436);
  static const Color info = Color(0xFF3A4A63);

  // Panel / hero art
  static const Color panelBlack = Color(0xFF0E0E0E);
  static const Color ring = Color(0xFFC99B3F);

  // Floating sensor badges (pastel chips around the hero art)
  static const Color badgeLeafBg = Color(0xFFE4EFE3);
  static const Color badgeLeafFg = Color(0xFF5F7F5A);
  static const Color badgeWaveBg = Color(0xFFE9EFF7);
  static const Color badgeWaveFg = Color(0xFF3A4A63);
  static const Color badgeTempBg = Color(0xFFF8E9E3);
  static const Color badgeTempFg = Color(0xFFB25A3C);
  static const Color badgeBeeBg = Color(0xFFF4EDD9);
  static const Color badgeBeeFg = Color(0xFF6B5B3E);

  // Hive stack gradient (light top -> dark bottom)
  static const Color hiveTop = Color(0xFFEAC46C);
  static const Color hiveMid = Color(0xFFD5A24A);
  static const Color hiveLow = Color(0xFFB9862F);
  static const Color hiveDoor = Color(0xFF2A1E10);

  // Gradient pairs
  static const accentGradient = LinearGradient(
    colors: [Color(0xFFEAC46C), Color(0xFFB9862F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFFF3DC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.accent2,
        surface: AppColors.bgSecondary,
        error: AppColors.error,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme)
          .copyWith(
            headlineLarge: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
            headlineMedium: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            headlineSmall: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            bodyLarge: GoogleFonts.inter(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
            bodyMedium: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            bodySmall: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            labelLarge: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: GoogleFonts.inter(color: AppColors.textSecondary),
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
        prefixStyle: GoogleFonts.inter(color: AppColors.accent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          elevation: 6,
          shadowColor: AppColors.accent.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.2),
        valueIndicatorColor: AppColors.bgElevated,
        valueIndicatorTextStyle: GoogleFonts.inter(color: AppColors.accent),
      ),
      dividerColor: AppColors.border,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgPrimary,
        selectedItemColor: AppColors.hiveLow,
        unselectedItemColor: AppColors.textSecondary,
      ),
    );
  }
}
