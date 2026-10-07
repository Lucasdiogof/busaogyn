import 'package:flutter/material.dart';

import '../theme/busao_tokens.dart';

/// Marca BusãoGyn: selo com ônibus + wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({this.showWordmark = true, this.size = 32, super.key});

  final bool showWordmark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    final seal = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tokens.plate,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.directions_bus_filled_rounded,
        size: size * 0.6,
        color: tokens.plateText,
      ),
    );
    if (!showWordmark) return ExcludeSemantics(child: seal);

    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: -0.6,
      height: 1,
    );
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
                  style: TextStyle(color: scheme.primary),
                ),
              ],
            ),
            style: style,
          ),
        ],
      ),
    );
  }
}

/// Número da linha no estilo do letreiro de destino (placa escura, dígitos
/// âmbar).
class RoutePlate extends StatelessWidget {
  const RoutePlate(this.routeId, {this.dense = false, super.key});

  final String routeId;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: 'Linha $routeId',
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minWidth: dense ? 44 : 58),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? Space.xs : Space.sm,
          vertical: dense ? Space.xxs : 6,
        ),
        decoration: BoxDecoration(
          color: tokens.plate,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        alignment: Alignment.center,
        child: Text(
          routeId,
          maxLines: 1,
          style: TextStyle(
            color: tokens.plateText,
            fontWeight: FontWeight.w900,
            fontSize: dense ? 14 : 20,
            letterSpacing: 1.2,
            height: 1.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

enum PillTone { neutral, positive, caution, danger, accent }

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
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final (fg, bg) = switch (tone) {
      PillTone.neutral => (tokens.scheduled, tokens.scheduledContainer),
      PillTone.positive => (tokens.realtime, tokens.realtimeContainer),
      PillTone.caution => (tokens.unconfirmed, tokens.unconfirmedContainer),
      PillTone.danger => (scheme.error, scheme.errorContainer),
      PillTone.accent => (scheme.primary, scheme.primaryContainer),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : Space.xs,
        vertical: dense ? 2 : Space.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 13 : 15, color: fg),
          const SizedBox(width: Space.xxs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
        child: Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// Estado vazio/erro com ícone, título, explicação e ação opcional.
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
    final scheme = Theme.of(context).colorScheme;
    final (fg, bg) = switch (tone) {
      PillTone.danger => (scheme.error, scheme.errorContainer),
      PillTone.caution => (tokens.unconfirmed, tokens.unconfirmedContainer),
      PillTone.accent => (scheme.primary, scheme.primaryContainer),
      _ => (tokens.mutedText, scheme.surfaceContainerHighest),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.lg),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: fg, size: 26),
          ),
          const SizedBox(height: Space.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (body != null) ...[
            const SizedBox(height: Space.xxs),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.mutedText),
            ),
          ],
          if (action != null) ...[const SizedBox(height: Space.md), action!],
        ],
      ),
    );
  }
}
