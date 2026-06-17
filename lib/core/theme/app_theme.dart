import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final inputFill = isDark ? AppColors.inputFill : AppColors.inputFillLight;

    const inter = GoogleFonts.inter;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bgColor,
      dividerColor: borderColor,
      cardColor: cardColor,
      colorScheme: isDark 
        ? const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: AppColors.bgDark,
            secondary: AppColors.accentLight,
            onSecondary: AppColors.bgDark,
            surface: AppColors.surfaceDark,
            onSurface: AppColors.textPrimaryDark,
            error: AppColors.error,
            onError: Colors.white,
          )
        : const ColorScheme.light(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            secondary: AppColors.accentDark,
            onSecondary: Colors.white,
            surface: AppColors.surfaceLight,
            onSurface: AppColors.textPrimaryLight,
            error: AppColors.error,
            onError: Colors.white,
          ),
      textTheme: GoogleFonts.interTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme
      ).copyWith(
        displayLarge: inter(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary),
        displayMedium: inter(fontSize: 26, fontWeight: FontWeight.w700, color: textPrimary),
        headlineLarge: inter(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium: inter(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: inter(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: inter(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
        bodyLarge: inter(fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: inter(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
        labelLarge: inter(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: inter(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: isDark ? AppColors.bgDark : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: inter(color: textSecondary, fontSize: 14),
        hintStyle: inter(color: AppColors.textHint, fontSize: 14),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.surfaceLightAlt : Colors.grey[200],
        selectedColor: AppColors.accent.withValues(alpha: 0.2),
        labelStyle: inter(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: borderColor),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceColor,
        selectedIconTheme: const IconThemeData(color: AppColors.accent),
        unselectedIconTheme: const IconThemeData(color: AppColors.textHint),
        selectedLabelTextStyle: inter(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: inter(color: AppColors.textHint, fontSize: 12),
        indicatorColor: AppColors.accent.withValues(alpha: 0.15),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: inter(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
