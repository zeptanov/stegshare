import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../platform_design/design_language.dart';

/// One ThemeData per (design language, brightness). Deliberately restrained:
/// neutral surfaces, a single accent, no gradients.
class AppTheme {
  static ThemeData build(DesignLanguage lang, Brightness b) {
    final dark = b == Brightness.dark;
    switch (lang) {
      case DesignLanguage.ios:
        return _base(
          b,
          accent: const Color(0xFF0A84FF),
          background: dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
          surface: dark ? const Color(0xFF1C1C1E) : Colors.white,
          radius: 16,
          font: '.SF Pro Text',
          ios: true,
        ).copyWith(
          cupertinoOverrideTheme: CupertinoThemeData(
            brightness: b,
            primaryColor: const Color(0xFF0A84FF),
            scaffoldBackgroundColor:
                dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
            barBackgroundColor:
                (dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7))
                    .withValues(alpha: 0.82),
          ),
        );
      case DesignLanguage.android:
        final scheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF4F6F52), brightness: b);
        return ThemeData(
            useMaterial3: true, colorScheme: scheme, brightness: b);
      case DesignLanguage.windows:
        return _base(
          b,
          accent: const Color(0xFF2E7D6B),
          background: dark ? const Color(0xFF202020) : const Color(0xFFF3F3F3),
          surface: dark ? const Color(0xFF2B2B2B) : Colors.white,
          radius: 4,
          font: 'Segoe UI',
        );
      case DesignLanguage.custom:
      case DesignLanguage.automatic:
        return _base(
          b,
          accent: const Color(0xFFD99A3E),
          background: dark ? const Color(0xFF151517) : const Color(0xFFF7F5F0),
          surface: dark ? const Color(0xFF212124) : const Color(0xFFFFFFFF),
          radius: 8,
          font: null,
        );
    }
  }

  static ThemeData _base(
    Brightness b, {
    required Color accent,
    required Color background,
    required Color surface,
    required double radius,
    required String? font,
    bool ios = false,
  }) {
    final dark = b == Brightness.dark;
    final onBg = dark ? const Color(0xFFEDEDED) : const Color(0xFF1B1B1B);
    final fieldSurface = ios
        ? (dark ? const Color(0xFF2C2C2E) : const Color(0xFFF1F1F6))
        : surface;
    final scheme = ColorScheme(
      brightness: b,
      primary: accent,
      onPrimary: dark ? Colors.black : Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      error: const Color(0xFFC62828),
      onError: Colors.white,
      surface: surface,
      onSurface: onBg,
      surfaceContainerHighest: ios
          ? fieldSurface
          : (dark ? const Color(0xFF2C2C30) : const Color(0xFFECEAE4)),
      outline: dark ? const Color(0xFF4A4A50) : const Color(0xFFCFCCC4),
    );
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      fontFamily: font,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
          color: surface, elevation: 0, shape: shape, margin: EdgeInsets.zero),
      filledButtonTheme:
          FilledButtonThemeData(style: FilledButton.styleFrom(shape: shape)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(shape: shape)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldSurface,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme:
          DividerThemeData(color: scheme.outline.withValues(alpha: 0.5)),
    );
  }
}
