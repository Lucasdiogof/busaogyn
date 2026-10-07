import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'busao_tokens.dart';

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, BusaoTokens.light);

  static ThemeData dark() => _build(Brightness.dark, BusaoTokens.dark);

  static ThemeData _build(Brightness brightness, BusaoTokens tokens) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: tokens.accent,
          brightness: brightness,
        ).copyWith(
          // `primary` é usado por componentes Material como cor de texto e
          // ícone; por isso é o âmbar legível, e o preenchimento âmbar vem de
          // [BusaoTokens.accent].
          primary: tokens.accentText,
          onPrimary: brightness == Brightness.dark
              ? tokens.onAccent
              : Colors.white,
          primaryContainer: tokens.accentSoft,
          onPrimaryContainer: tokens.strongText,
          secondary: tokens.accentText,
          surface: tokens.background,
          onSurface: tokens.strongText,
          onSurfaceVariant: tokens.mutedText,
          surfaceContainerHighest: tokens.raised,
          outline: tokens.hairline,
          outlineVariant: tokens.hairline,
          error: tokens.danger,
        );

    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      useMaterial3: true,
      fontFamily: BusaoFonts.sans,
      scaffoldBackgroundColor: tokens.background,
      visualDensity: VisualDensity.standard,
    );
    final text = base.textTheme.apply(
      bodyColor: tokens.strongText,
      displayColor: tokens.strongText,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.field - 2),
    );
    const buttonText = TextStyle(
      fontFamily: BusaoFonts.sans,
      fontWeight: FontWeight.w600,
      fontSize: 15,
    );

    return base.copyWith(
      extensions: [tokens],
      textTheme: text.copyWith(
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.4),
        bodySmall: text.bodySmall?.copyWith(height: 1.4),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        labelMedium: text.labelMedium?.copyWith(fontWeight: FontWeight.w500),
        labelSmall: text.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: tokens.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: tokens.hairline),
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.hairline, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.onAccent,
          disabledBackgroundColor: tokens.raised,
          disabledForegroundColor: tokens.mutedText,
          minimumSize: const Size(48, 48),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.strongText,
          backgroundColor: tokens.card,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: tokens.hairline),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accentText,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: tokens.softText),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: BusaoFonts.sans,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? tokens.accent
                  : tokens.hairline,
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? tokens.accentSoft
                : tokens.background,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? tokens.strongText
                : tokens.softText,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        hintStyle: TextStyle(color: tokens.mutedText),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.accentText,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: tokens.strongText,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        textStyle: TextStyle(
          color: tokens.background,
          fontFamily: BusaoFonts.sans,
          fontSize: 12,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
