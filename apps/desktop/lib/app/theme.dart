import 'package:flutter/material.dart';

class AccountCareTheme {
  AccountCareTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,

      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1565C0),
        brightness: Brightness.light,
      ),

      scaffoldBackgroundColor: const Color(0xFFF7F8FA),

      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
      ),

      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),

      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
      ),

      visualDensity: VisualDensity.standard,
    );
  }
}