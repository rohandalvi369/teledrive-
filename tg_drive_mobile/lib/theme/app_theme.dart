import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Dark mode (desktop version)
  static const Color bg = Color(0xFF000000);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceElevated = Color(0xFF1A1A1A);
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryGlow = Color(0x4D6C63FF);
  static const Color accent = Color(0xFF5A52E0);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFF4F4F5);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color border = Color(0xFF2A2A2A);
  static const Color card = Color(0xFF1A1A1A);
  static const Color gradientStart = Color(0xFF6C63FF);
  static const Color gradientEnd = Color(0xFF5A52E0);

  // Light mode (desktop version)
  static const Color lightBg = Color(0xFFF0EAD6);
  static const Color lightSurface = Color(0xFFE8E0CC);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF24A1DE);
  static const Color lightPrimaryGlow = Color(0x4D24A1DE);
  static const Color lightAccent = Color(0xFF1E8FC7);
  static const Color lightSuccess = Color(0xFF22C55E);
  static const Color lightError = Color(0xFFEF4444);
  static const Color lightTextPrimary = Color(0xFF222222);
  static const Color lightTextSecondary = Color(0xFF5C5C5C);
  static const Color lightBorder = Color(0xFFD5CCB8);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightGradientStart = Color(0xFF24A1DE);
  static const Color lightGradientEnd = Color(0xFF1E8FC7);

  // File type colors (shared)
  static const Color fileImage = Color(0xFF3B82F6);
  static const Color fileVideo = Color(0xFF8B5CF6);
  static const Color fileAudio = Color(0xFF22C55E);
  static const Color fileDoc = Color(0xFFF97316);
  static const Color filePdf = Color(0xFFEF4444);
  static const Color fileArchive = Color(0xFFA16207);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        headlineMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        headlineSmall: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceElevated,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerColor: AppColors.border,
      focusColor: AppColors.primary,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightPrimary,
        secondary: AppColors.lightAccent,
        surface: AppColors.lightSurface,
        error: AppColors.lightError,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightTextPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
        headlineMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
        headlineSmall: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.lightTextPrimary),
        titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.lightTextPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.lightTextPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.lightTextPrimary),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.lightTextSecondary),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.lightTextPrimary),
        labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.lightTextSecondary),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.lightTextSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBg.withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.lightTextPrimary),
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceElevated,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.lightTextSecondary),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.lightTextSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.lightPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.lightError),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightPrimary,
          side: const BorderSide(color: AppColors.lightBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightSurfaceElevated,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.lightBorder, thickness: 1),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.lightTextPrimary,
        unselectedLabelColor: AppColors.lightTextSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.lightPrimary,
        foregroundColor: Colors.white,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceElevated,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.lightTextPrimary),
        side: const BorderSide(color: AppColors.lightBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerColor: AppColors.lightBorder,
      focusColor: AppColors.lightPrimary,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
    );
  }
}
