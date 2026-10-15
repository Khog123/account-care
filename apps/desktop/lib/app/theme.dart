import 'package:flutter/material.dart';

class AccountCareTheme {
  AccountCareTheme._();

  static const navy = Color(0xFF0B1F3A);
  static const navyDeep = Color(0xFF08182D);
  static const blue = Color(0xFF0866F5);
  static const workspace = Color(0xFFF2F6FC);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE3EAF4);
  static const text = Color(0xFF14243B);
  static const muted = Color(0xFF687991);
  static const green = Color(0xFF159957);
  static const red = Color(0xFFE5484D);
  static const orange = Color(0xFFF59E0B);
  static const purple = Color(0xFF7846E8);
  static const teal = Color(0xFF20A4B8);

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: blue,
      onPrimary: Colors.white,
      secondary: teal,
      onSecondary: Colors.white,
      error: red,
      onError: Colors.white,
      surface: card,
      onSurface: text,
      primaryContainer: Color(0xFFE5EFFF),
      onPrimaryContainer: Color(0xFF0B3D91),
      secondaryContainer: Color(0xFFDDF6F4),
      onSecondaryContainer: Color(0xFF075D65),
      errorContainer: Color(0xFFFFE9E8),
      onErrorContainer: Color(0xFF8C2025),
      surfaceContainerHighest: Color(0xFFEDF2F8),
      onSurfaceVariant: muted,
      outline: Color(0xFFCBD6E5),
      outlineVariant: border,
      shadow: Color(0x140B1F3A),
      scrim: Color(0x66000000),
      inverseSurface: navy,
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFF9CC2FF),
      surfaceTint: blue,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: workspace,
      visualDensity: VisualDensity.compact,
      fontFamily: 'Segoe UI',
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(bodyColor: text, displayColor: text, fontFamily: 'Segoe UI')
          .copyWith(
            headlineSmall: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.45,
              color: text,
            ),
            titleLarge: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: text,
            ),
            titleMedium: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: text,
            ),
            titleSmall: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: text,
            ),
            bodyMedium: const TextStyle(fontSize: 12, height: 1.4, color: text),
            bodySmall: const TextStyle(
              fontSize: 11,
              height: 1.35,
              color: muted,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: workspace,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        toolbarHeight: 58,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        hintStyle: const TextStyle(fontSize: 12, color: muted),
        labelStyle: const TextStyle(fontSize: 12, color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: blue, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: red, width: 1.4),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: muted, size: 19),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: blue,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
