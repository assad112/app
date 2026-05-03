import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global design tokens — import in any screen that needs brand colours.
class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFFFF7A1A);
  static const primaryDark = Color(0xFFCC6000);
  static const primarySoft = Color(0xFFFFF3EA);

  // Dark backgrounds
  static const navy = Color(0xFF0D1732);
  static const navyMid = Color(0xFF182B57);
  static const blue = Color(0xFF243B73);

  // Light backgrounds
  static const background = Color(0xFFF1F5F9);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF8FAFC);

  // Text
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textTertiary = Color(0xFF94A3B8);

  // Borders
  static const border = Color(0xFFE2E8F0);
  static const borderDark = Color(0xFFCBD5E1);

  // Semantic
  static const success = Color(0xFF10B981);
  static const successSoft = Color(0xFFD1FAE5);
  static const error = Color(0xFFEF4444);
  static const errorSoft = Color(0xFFFEE2E2);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFEF3C7);
  static const info = Color(0xFF3B82F6);
  static const infoSoft = Color(0xFFDBEAFE);
}

class AppTheme {
  AppTheme._();

  static const _seed = AppColors.primary;
  static const _background = AppColors.background;
  static const _surface = AppColors.surface;
  static const _textPrimary = AppColors.textPrimary;

  static ThemeData light(Locale locale) {
    final textTheme = _textTheme(
      locale,
    ).apply(bodyColor: _textPrimary, displayColor: _textPrimary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.light,
        primary: _seed,
        surface: _surface,
      ),
      scaffoldBackgroundColor: _background,
      textTheme: textTheme,
      fontFamily: textTheme.bodyMedium?.fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: _background,
        foregroundColor: _textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: _textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _seed, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textTertiary,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        prefixIconColor: AppColors.textTertiary,
        suffixIconColor: AppColors.textTertiary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 68,
        indicatorColor: const Color(0x18FF7A1A),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: _seed,
            );
          }
          return textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 22);
          }
          return const IconThemeData(color: AppColors.textTertiary, size: 22);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _seed,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: AppColors.border, width: 1.5),
          foregroundColor: _textPrimary,
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _seed,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: AppColors.primary,
      ),
    );
  }

  static TextTheme _textTheme(Locale locale) {
    if (locale.languageCode == 'ar') {
      return GoogleFonts.cairoTextTheme();
    }
    return GoogleFonts.manropeTextTheme();
  }
}
