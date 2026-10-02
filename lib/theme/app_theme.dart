import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF0D7A4B);
  static const primaryDark = Color(0xFF075D39);
  static const primaryLight = Color(0xFF52C184);
  static const background = Color(0xFFF5F8F6);
  static const surfaceSoft = Color(0xFFECF3EF);
  static const textPrimary = Color(0xFF17241D);
  static const textSecondary = Color(0xFF66766E);
  static const green = Color(0xFF249B5C);
  static const greenSoft = Color(0xFFE3F3E9);
  static const orange = Color(0xFFC97A1B);
  static const orangeSoft = Color(0xFFFFF0DC);
  static const blue = Color(0xFF4678B8);
  static const blueSoft = Color(0xFFEAF1F9);
  static const red = Color(0xFFDC4C5C);
  static const redSoft = Color(0xFFFCE8EB);
  static const border = Color(0xFFD7E2DB);
}

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      surface: Colors.white,
      error: AppColors.red,
    ).copyWith(
      primaryContainer: AppColors.greenSoft,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: const Color(0xFF507B68),
      secondaryContainer: AppColors.surfaceSoft,
      onSecondaryContainer: AppColors.textPrimary,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: const Color(0xFFF0F5F2),
      surfaceContainerHigh: AppColors.surfaceSoft,
      surfaceContainerHighest: const Color(0xFFE4ECE7),
      outline: AppColors.border,
      outlineVariant: const Color(0xFFE2EAE5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'sans-serif',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : const Color(0xFFA8AFB4),
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : const Color(0xFFB2B8BC),
            size: 23,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryLight,
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
      surface: const Color(0xFF17211C),
      error: const Color(0xFFFF7A88),
    ).copyWith(
      primaryContainer: const Color(0xFF204E37),
      onPrimaryContainer: const Color(0xFFC5F2D6),
      secondary: const Color(0xFF9CCBB5),
      secondaryContainer: const Color(0xFF294237),
      surfaceContainerLow: const Color(0xFF101813),
      surfaceContainer: const Color(0xFF152019),
      surfaceContainerHigh: const Color(0xFF1C2922),
      surfaceContainerHighest: const Color(0xFF26352D),
      outline: const Color(0xFF405047),
      outlineVariant: const Color(0xFF2F3E36),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0D1511),
      fontFamily: 'sans-serif',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Color(0xFF0E6C3E),
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Color(0xFF17211C),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: const Color(0xFF131D18),
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryLight
                : const Color(0xFF91A198),
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryLight
                : const Color(0xFF91A198),
            size: 23,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFE7F0EA),
        contentTextStyle: const TextStyle(color: Color(0xFF142019)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF17211C),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF33423A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF33423A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primaryLight,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF7A88)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFFF7A88),
            width: 1.5,
          ),
        ),
      ),
      dividerColor: const Color(0xFF33423A),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF17211C),
      ),
    );
  }
}
