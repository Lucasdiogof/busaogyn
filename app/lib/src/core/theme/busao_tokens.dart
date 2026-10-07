import 'package:flutter/material.dart';

/// Escala de espaçamento (múltiplos de 4).
abstract final class Space {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class Radii {
  static const chip = 8.0;
  static const card = 16.0;
  static const panel = 24.0;
  static const pill = 999.0;
}

/// Pontos de quebra do layout. Abaixo de [panel] o painel vira bottom sheet.
abstract final class Breakpoints {
  static const panel = 720.0;
  static const wide = 1100.0;
}

/// Cores semânticas do produto que o [ColorScheme] não cobre.
@immutable
class BusaoTokens extends ThemeExtension<BusaoTokens> {
  const BusaoTokens({
    required this.realtime,
    required this.realtimeContainer,
    required this.scheduled,
    required this.scheduledContainer,
    required this.unconfirmed,
    required this.unconfirmedContainer,
    required this.plate,
    required this.plateText,
    required this.floatingSurface,
    required this.hairline,
    required this.mutedText,
    required this.shadow,
  });

  /// Previsão com GPS da fonte (verde).
  final Color realtime;
  final Color realtimeContainer;

  /// Horário de tabela (neutro).
  final Color scheduled;
  final Color scheduledContainer;

  /// Qualidade desconhecida, posição desatualizada (âmbar).
  final Color unconfirmed;
  final Color unconfirmedContainer;

  /// Placa de linha inspirada no letreiro de destino dos ônibus.
  final Color plate;
  final Color plateText;

  /// Superfícies que flutuam sobre o mapa.
  final Color floatingSurface;
  final Color hairline;
  final Color mutedText;
  final Color shadow;

  static const light = BusaoTokens(
    realtime: Color(0xFF0B8A5F),
    realtimeContainer: Color(0xFFDCF5EA),
    scheduled: Color(0xFF586174),
    scheduledContainer: Color(0xFFEBEEF3),
    unconfirmed: Color(0xFFA35A00),
    unconfirmedContainer: Color(0xFFFCEFD9),
    plate: Color(0xFF111827),
    plateText: Color(0xFFFFC53D),
    floatingSurface: Color(0xFFFFFFFF),
    hairline: Color(0xFFE3E7EE),
    mutedText: Color(0xFF5D6677),
    shadow: Color(0x2E0F172A),
  );

  static const dark = BusaoTokens(
    realtime: Color(0xFF3DD9A0),
    realtimeContainer: Color(0xFF0E3A2C),
    scheduled: Color(0xFFA3ADC2),
    scheduledContainer: Color(0xFF232E45),
    unconfirmed: Color(0xFFF7B548),
    unconfirmedContainer: Color(0xFF3D2B0B),
    plate: Color(0xFF05080F),
    plateText: Color(0xFFFFC53D),
    floatingSurface: Color(0xFF131C30),
    hairline: Color(0xFF26324B),
    mutedText: Color(0xFF9BA6BC),
    shadow: Color(0x66000000),
  );

  @override
  BusaoTokens copyWith() => this;

  @override
  BusaoTokens lerp(ThemeExtension<BusaoTokens>? other, double t) {
    if (other is! BusaoTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return BusaoTokens(
      realtime: mix(realtime, other.realtime),
      realtimeContainer: mix(realtimeContainer, other.realtimeContainer),
      scheduled: mix(scheduled, other.scheduled),
      scheduledContainer: mix(scheduledContainer, other.scheduledContainer),
      unconfirmed: mix(unconfirmed, other.unconfirmed),
      unconfirmedContainer: mix(
        unconfirmedContainer,
        other.unconfirmedContainer,
      ),
      plate: mix(plate, other.plate),
      plateText: mix(plateText, other.plateText),
      floatingSurface: mix(floatingSurface, other.floatingSurface),
      hairline: mix(hairline, other.hairline),
      mutedText: mix(mutedText, other.mutedText),
      shadow: mix(shadow, other.shadow),
    );
  }
}

extension BusaoThemeContext on BuildContext {
  BusaoTokens get tokens => Theme.of(this).extension<BusaoTokens>()!;
}
