import 'package:flutter/material.dart';

import 'busao_tokens.dart';

abstract final class AppTheme {
  static const _signalBlue = Color(0xFF1F5EFF);

  static ThemeData light() => _build(
    ColorScheme.fromSeed(
      seedColor: _signalBlue,
      primary: _signalBlue,
      surface: const Color(0xFFF5F7FB),
      onSurface: const Color(0xFF0F172A),
      surfaceContainerHighest: const Color(0xFFE9EDF4),
      error: const Color(0xFFD12C1F),
    ),
    BusaoTokens.light,
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: _signalBlue,
      brightness: Brightness.dark,
      primary: const Color(0xFF7C9DFF),
      onPrimary: const Color(0xFF071233),
      surface: const Color(0xFF0B1120),
      onSurface: const Color(0xFFE7EBF3),
      surfaceContainerHighest: const Color(0xFF1B2640),
      error: const Color(0xFFFF7A6E),
    ),
    BusaoTokens.dark,
  );

  static ThemeData _build(ColorScheme scheme, BusaoTokens tokens) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
    );
    const tabular = [FontFeature.tabularFigures()];
    final text = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      extensions: [tokens],
      textTheme: text.copyWith(
        // Tempos de chegada: grandes, pesados e com dígitos alinhados.
        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          fontFeatures: tabular,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          fontFeatures: tabular,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        labelMedium: text.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        labelSmall: text.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: tokens.floatingSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: tokens.hairline),
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.hairline, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card - 4),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          side: BorderSide(color: tokens.hairline, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card - 4),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.card - 4),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.card - 4),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.card - 4),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
