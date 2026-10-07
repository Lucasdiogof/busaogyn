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
  static const plate = 12.0;
  static const field = 16.0;
  static const card = 16.0;
  static const header = 20.0;
  static const panel = 24.0;
  static const dock = 28.0;
  static const pill = 999.0;
}

/// Medidas fixas dos elementos que flutuam sobre o mapa.
abstract final class Chrome {
  /// Pílulas do topo (marca e status).
  static const pill = 44.0;

  /// Cartão de contexto (busca, ponto, ônibus, ajustes).
  static const header = 64.0;
  static const dock = 70.0;

  /// Margem lateral dos elementos flutuantes.
  static const gutter = 16.0;

  /// Largura máxima da coluna central em tablet e desktop.
  static const column = 460.0;
}

/// Pontos de quebra do layout. Abaixo de [panel] o painel vira bottom sheet.
abstract final class Breakpoints {
  static const panel = 720.0;
}

/// Famílias empacotadas em `assets/fonts/geist` (SIL OFL 1.1).
abstract final class BusaoFonts {
  static const sans = 'Geist';
  static const mono = 'GeistMono';
}

/// Números do produto (linha, minutos, ônibus, idades): Geist Mono com
/// dígitos tabulares.
TextStyle monoStyle(TextStyle? base) => (base ?? const TextStyle()).copyWith(
  fontFamily: BusaoFonts.mono,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Cores semânticas do produto que o [ColorScheme] não cobre.
///
/// O âmbar é só acento visual (marca, seleção, ônibus no mapa). Qualidade
/// dos dados tem cores próprias: verde = tempo real, neutro = programado,
/// laranja = não confirmado ou desatualizado.
@immutable
class BusaoTokens extends ThemeExtension<BusaoTokens> {
  const BusaoTokens({
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.accentText,
    required this.realtime,
    required this.realtimeContainer,
    required this.scheduled,
    required this.scheduledContainer,
    required this.unconfirmed,
    required this.unconfirmedContainer,
    required this.danger,
    required this.background,
    required this.card,
    required this.raised,
    required this.glass,
    required this.glassBorder,
    required this.panel,
    required this.hairline,
    required this.strongText,
    required this.softText,
    required this.mutedText,
    required this.shadow,
    required this.brandTile,
  });

  /// Âmbar de destaque (preenchimentos e bordas).
  final Color accent;
  final Color onAccent;

  /// Fundo de itens selecionados.
  final Color accentSoft;

  /// Âmbar legível como texto sobre a superfície do tema.
  final Color accentText;

  /// Previsão com GPS da fonte (verde).
  final Color realtime;
  final Color realtimeContainer;

  /// Horário de tabela (neutro).
  final Color scheduled;
  final Color scheduledContainer;

  /// Qualidade desconhecida, posição desatualizada (laranja, distinto do
  /// acento âmbar).
  final Color unconfirmed;
  final Color unconfirmedContainer;
  final Color danger;

  final Color background;

  /// Linhas de chegada e blocos dentro do painel.
  final Color card;
  final Color raised;

  /// Superfícies que flutuam sobre o mapa (quase opacas: o mapa nativo não
  /// passa por filtros de desfoque do Flutter).
  final Color glass;
  final Color glassBorder;

  /// Painel com a lista (sheet e coluna central).
  final Color panel;
  final Color hairline;
  final Color strongText;
  final Color softText;
  final Color mutedText;
  final Color shadow;
  final Color brandTile;

  static const light = BusaoTokens(
    accent: Color(0xFFFFC53D),
    onAccent: Color(0xFF1A1300),
    accentSoft: Color(0xFFFFF0C2),
    accentText: Color(0xFF7A4F00),
    realtime: Color(0xFF0B7A54),
    realtimeContainer: Color(0xFFD6F3E6),
    scheduled: Color(0xFF4A463D),
    scheduledContainer: Color(0xFFE4E2DC),
    unconfirmed: Color(0xFFB54708),
    unconfirmedContainer: Color(0xFFFDEBDD),
    danger: Color(0xFFB4281C),
    background: Color(0xFFFFFFFF),
    card: Color(0xFFF4F3F0),
    raised: Color(0xFFE4E2DC),
    glass: Color(0xEBFFFFFF),
    glassBorder: Color(0x24191919),
    panel: Color(0xFFFFFFFF),
    hairline: Color(0xFFDEDBD2),
    strongText: Color(0xFF0B0A08),
    softText: Color(0xFF4A463D),
    mutedText: Color(0xFF5F5A4E),
    shadow: Color(0x2E0F172A),
    brandTile: Color(0xFF0B0A08),
  );

  static const dark = BusaoTokens(
    accent: Color(0xFFFFC53D),
    onAccent: Color(0xFF1A1300),
    accentSoft: Color(0xFF3A2B06),
    accentText: Color(0xFFFFC53D),
    realtime: Color(0xFF3DD9A0),
    realtimeContainer: Color(0xFF0E3A2C),
    scheduled: Color(0xFFD9D9D9),
    scheduledContainer: Color(0xFF2A251B),
    unconfirmed: Color(0xFFFF9B57),
    unconfirmedContainer: Color(0xFF3A1F0C),
    danger: Color(0xFFFF8A7A),
    background: Color(0xFF0B0A08),
    card: Color(0xFF15120C),
    raised: Color(0xFF221D12),
    glass: Color(0xD60B0A08),
    glassBorder: Color(0x1FF6F6F6),
    panel: Color(0xFF0B0A08),
    hairline: Color(0xFF2C261A),
    strongText: Color(0xFFFFFFFF),
    softText: Color(0xFFD9D9D9),
    mutedText: Color(0xFFC2C1C1),
    shadow: Color(0x73000000),
    brandTile: Color(0xFF0B0A08),
  );

  @override
  BusaoTokens copyWith() => this;

  @override
  BusaoTokens lerp(ThemeExtension<BusaoTokens>? other, double t) {
    if (other is! BusaoTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return BusaoTokens(
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentSoft: mix(accentSoft, other.accentSoft),
      accentText: mix(accentText, other.accentText),
      realtime: mix(realtime, other.realtime),
      realtimeContainer: mix(realtimeContainer, other.realtimeContainer),
      scheduled: mix(scheduled, other.scheduled),
      scheduledContainer: mix(scheduledContainer, other.scheduledContainer),
      unconfirmed: mix(unconfirmed, other.unconfirmed),
      unconfirmedContainer: mix(
        unconfirmedContainer,
        other.unconfirmedContainer,
      ),
      danger: mix(danger, other.danger),
      background: mix(background, other.background),
      card: mix(card, other.card),
      raised: mix(raised, other.raised),
      glass: mix(glass, other.glass),
      glassBorder: mix(glassBorder, other.glassBorder),
      panel: mix(panel, other.panel),
      hairline: mix(hairline, other.hairline),
      strongText: mix(strongText, other.strongText),
      softText: mix(softText, other.softText),
      mutedText: mix(mutedText, other.mutedText),
      shadow: mix(shadow, other.shadow),
      brandTile: mix(brandTile, other.brandTile),
    );
  }
}

extension BusaoThemeContext on BuildContext {
  BusaoTokens get tokens => Theme.of(this).extension<BusaoTokens>()!;
}
