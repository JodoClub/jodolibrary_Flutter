import 'package:flutter/material.dart';

/// Central theme & color palette for jodolibrary
class AppColors {
  // Brand Primary (#0f4dd2 - Royal Blue)
  static const Color primary = Color(0xFF0F4DD2);
  static const Color primaryDark = Color(0xFF0A3EB2);
  static const Color primaryLight = Color(0xFFEEF3FF);

  // Brand Secondary (#26b891 - Mint / Teal Green)
  static const Color secondary = Color(0xFF26B891);
  static const Color secondaryDark = Color(0xFF1E9C7A);
  static const Color secondaryLight = Color(0xFFECF9F5);

  // Black & White / Neutrals
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF090D16); // Deep rich black for hero cards & dark drawers

  // Indigo mappings (mapped to Primary #0F4DD2 and Deep Black for seamless backward compatibility)
  static const Color indigo950 = Color(0xFF090D16); // Deep sleek black/dark container
  static const Color indigo900 = Color(0xFF0F172A);
  static const Color indigo800 = Color(0xFF0F4DD2); // Primary
  static const Color indigo50 = Color(0xFFEEF3FF);  // Primary soft tint
  static const Color indigo100 = Color(0xFFDBE6FE);
  static const Color indigo200 = Color(0xFFB5CDFD);
  static const Color indigo300 = Color(0xFF8FB5FC);

  // Orange mappings (re-routed to Primary #0F4DD2 & Secondary #26B891 so all primary CTAs, buttons, and borders update)
  static const Color orange500 = Color(0xFF0F4DD2); // Primary #0F4DD2
  static const Color orange600 = Color(0xFF0A3EB2);
  static const Color orange400 = Color(0xFF26B891); // Secondary accent #26B891
  static const Color orange100 = Color(0xFFDBE6FE);
  static const Color orange50 = Color(0xFFEEF3FF);

  // Slate Neutrals (Clean Black / White / Grey shades)
  static const Color slate950 = Color(0xFF000000);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);

  // Emerald mappings (re-routed to Secondary #26B891)
  static const Color emerald600 = Color(0xFF1E9C7A);
  static const Color emerald500 = Color(0xFF26B891); // Secondary #26B891
  static const Color emerald400 = Color(0xFF48C9A6);
  static const Color emerald300 = Color(0xFF78DCC2);
  static const Color emerald100 = Color(0xFFD3F4EB);
  static const Color emerald50 = Color(0xFFECF9F5);

  // Amber (warning/attention)
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber300 = Color(0xFFFCD34D);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber50 = Color(0xFFFFFBEB);

  // Rose (error/destructive)
  static const Color rose600 = Color(0xFFE11D48);
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color rose100 = Color(0xFFFFE4E6);
  static const Color rose50 = Color(0xFFFFF1F2);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.slate50,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: Colors.white,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }
}
