import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/busao_tokens.dart';

/// Superfície que flutua sobre o mapa: quase opaca, borda fina e sombra.
///
/// Sem `BackdropFilter`: o mapa é uma platform view (Android/iOS) ou um
/// elemento HTML (Web) e não passa pelo filtro; o desfoque só custaria
/// desempenho.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.radius = Radii.header,
    this.padding = EdgeInsets.zero,
    this.elevated = true,
    this.solid = false,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final double radius;

  /// Borda de destaque (por exemplo, erro); padrão é a borda do vidro.
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  /// Painéis com listas: quase sem transparência, para o mapa não competir
  /// com o texto.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? tokens.panel : tokens.glass,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null
            ? Border.all(color: tokens.glassBorder)
            : Border.all(color: borderColor!, width: 1.5),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: tokens.shadow,
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Marca BusãoGyn: símbolo da logo oficial + wordmark.
///
/// O símbolo vem de `assets/brand/logo-mark.png` (gerado por
/// `tool/generate_brand_assets.py` a partir de `docs/brand/source`); o letreiro
/// "BUSÃO GYN" fica ilegível neste tamanho, então o nome textual acompanha.
class BrandMark extends StatelessWidget {
  const BrandMark({this.showWordmark = true, this.size = 32, super.key});

  static const symbolAsset = 'assets/brand/logo-mark.png';

  final bool showWordmark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final seal = Image.asset(
      symbolAsset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
    if (!showWordmark) return ExcludeSemantics(child: seal);

    return Semantics(
      label: 'BusãoGyn',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seal,
          const SizedBox(width: Space.xs),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Busão'),
                TextSpan(
                  text: 'Gyn',
                  style: TextStyle(color: tokens.accentText),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1,
              color: tokens.strongText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Número da linha: placa com contorno âmbar e dígitos em Geist Mono.
/// [filled] destaca a linha do ônibus acompanhado.
class RoutePlate extends StatelessWidget {
  const RoutePlate(
    this.routeId, {
    this.dense = false,
    this.filled = false,
    super.key,
  });

  final String routeId;
  final bool dense;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final height = dense ? 36.0 : 44.0;
    return Semantics(
      label: 'Linha $routeId',
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minWidth: dense ? 44 : 52),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: filled ? tokens.accent : tokens.background,
          borderRadius: BorderRadius.circular(Radii.plate),
          border: Border.all(color: tokens.accent, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          routeId,
          maxLines: 1,
          style: monoStyle(
            TextStyle(
              color: filled ? tokens.onAccent : tokens.strongText,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 14 : 16,
              letterSpacing: -0.3,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

enum PillTone { neutral, positive, caution, danger, accent }

(Color fg, Color bg) pillColors(BuildContext context, PillTone tone) {
  final tokens = context.tokens;
  return switch (tone) {
    PillTone.neutral => (tokens.scheduled, tokens.scheduledContainer),
    PillTone.positive => (tokens.realtime, tokens.realtimeContainer),
    PillTone.caution => (tokens.unconfirmed, tokens.unconfirmedContainer),
    PillTone.danger => (
      tokens.danger,
      Theme.of(context).colorScheme.errorContainer,
    ),
    PillTone.accent => (tokens.strongText, tokens.accentSoft),
  };
}

/// Ícone + texto: estados nunca dependem só de cor.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.icon,
    required this.label,
    this.tone = PillTone.neutral,
    this.dense = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final PillTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = pillColors(context, tone);
    return Container(
      height: dense ? 20 : 32,
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dense ? Radii.pill : 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 11 : 15, color: fg),
          SizedBox(width: dense ? 3 : 6),
          Flexible(
            child: Text(
              dense ? label.toUpperCase() : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: dense ? 9.5 : 13,
                fontWeight: dense ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: dense ? 0.4 : 0,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Título de seção do painel: ícone âmbar + rótulo em caixa alta.
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    required this.icon,
    required this.label,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
      child: Row(
        children: [
          Icon(icon, size: 17, color: tokens.accentText),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Semantics(
              container: true,
              header: true,
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: tokens.softText,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Nota de rodapé do painel (ícone de informação + texto pequeno).
class FootNote extends StatelessWidget {
  const FootNote({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: tokens.softText,
            ),
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: tokens.mutedText,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador de cor. Com [pulsing], pulsa duas vezes ao aparecer e a cada
/// mudança de [pulseKey] (dado novo), sem animar para sempre.
class StatusDot extends StatefulWidget {
  const StatusDot({
    required this.color,
    this.pulsing = false,
    this.pulseKey,
    super.key,
  });

  final Color color;
  final bool pulsing;
  final Object? pulseKey;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _pulse.addStatusListener(_onStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didUpdateWidget(covariant StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulsing != widget.pulsing ||
        oldWidget.pulseKey != widget.pulseKey) {
      _start();
    }
  }

  void _start() {
    if (!mounted) return;
    if (!widget.pulsing || MediaQuery.disableAnimationsOf(context)) {
      _remaining = 0;
      _pulse
        ..stop()
        ..value = 0;
      return;
    }
    _remaining = 2;
    _pulse.forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _remaining--;
    if (_remaining > 0) {
      _pulse.forward(from: 0);
    } else {
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 18,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = _pulse.value;
            return Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (t > 0)
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.6 * (1 - t)),
                        spreadRadius: 9 * t,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Reconstrói [builder] periodicamente para textos de idade ("há 25 s").
class PeriodicRebuild extends StatefulWidget {
  const PeriodicRebuild({
    required this.builder,
    this.interval = const Duration(seconds: 5),
    super.key,
  });

  final WidgetBuilder builder;
  final Duration interval;

  @override
  State<PeriodicRebuild> createState() => _PeriodicRebuildState();
}

class _PeriodicRebuildState extends State<PeriodicRebuild> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// Bloco pulsante para carregamento; não anuncia nada a leitores de tela.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    this.height = 16,
    this.width,
    this.radius = Radii.chip,
    super.key,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
        child: Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: context.tokens.raised,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// Estado vazio/erro com ícone, título, explicação e ação opcional, dentro
/// de uma moldura tracejada como na prévia.
class MessageView extends StatelessWidget {
  const MessageView({
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.tone = PillTone.neutral,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final Color fg = switch (tone) {
      PillTone.neutral => tokens.softText,
      _ => pillColors(context, tone).$1,
    };

    return CustomPaint(
      key: const ValueKey('message-view'),
      painter: _DashedBorderPainter(color: tokens.hairline),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.lg,
          Space.md,
          Space.lg,
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 26),
            const SizedBox(height: Space.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (body != null) ...[
              const SizedBox(height: Space.xxs),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.softText),
              ),
            ],
            if (action != null) ...[const SizedBox(height: Space.md), action!],
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(Radii.header),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
