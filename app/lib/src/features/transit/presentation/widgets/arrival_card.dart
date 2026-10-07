import 'package:flutter/material.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../../domain/entities/arrival.dart';
import '../cubit/stop_arrivals_cubit.dart';
import '../formatters/transit_labels.dart';

class QualityBadge extends StatelessWidget {
  const QualityBadge(this.quality, {this.dense = true, super.key});

  final ArrivalQuality quality;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (quality) {
      ArrivalQuality.realtime => (Icons.sensors_rounded, PillTone.positive),
      ArrivalQuality.scheduled => (Icons.schedule_rounded, PillTone.neutral),
      ArrivalQuality.unknown => (Icons.help_outline_rounded, PillTone.caution),
    };
    return Semantics(
      label: qualityLabel(quality),
      excludeSemantics: true,
      child: StatusPill(
        icon: icon,
        label: dense ? qualityShortLabel(quality) : qualityLabel(quality),
        tone: tone,
        dense: dense,
      ),
    );
  }
}

/// Minutos em Geist Mono: número grande, unidade pequena.
class MinutesText extends StatelessWidget {
  const MinutesText(
    this.minutes, {
    this.size = 20,
    this.color,
    this.unit = 'min',
    super.key,
  });

  final int? minutes;
  final double size;
  final Color? color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final value = switch (minutes) {
      null => '—',
      <= 0 => '< 1',
      final m => '$m',
    };
    final color = this.color ?? tokens.strongText;
    return Semantics(
      label: minutesSemantics(minutes),
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: value),
            if (minutes != null && unit.isNotEmpty)
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
          ],
        ),
        maxLines: 1,
        style: monoStyle(
          TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Uma linha do ponto: placa, destino, próxima chegada e o ônibus que pode
/// ser acompanhado. A chegada seguinte aparece numa faixa abaixo.
class ArrivalCard extends StatelessWidget {
  const ArrivalCard({
    required this.group,
    required this.tracking,
    required this.onTrack,
    super.key,
  });

  final ArrivalGroup group;
  final TrackingInfo? tracking;
  final ValueChanged<String> onTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final next = group.next;
    final following = group.following;
    final nextQuality = displayQuality(next);
    final tracked = _isTracked(next) || _isTracked(following);

    return Semantics(
      container: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: tracked ? tokens.accent : tokens.hairline,
            width: tracked ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(child: RoutePlate(group.routeId)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.destination == null
                              ? 'Destino não informado'
                              : destinationLabel(group.destination!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          following == null
                              ? 'sem seguinte'
                              : 'depois ${minutesLabel(following.minutes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: monoStyle(
                            TextStyle(fontSize: 11.5, color: tokens.mutedText),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.xs),
                  Semantics(
                    container: true,
                    label:
                        'Próximo: ${minutesSemantics(next.minutes)}, '
                        '${qualityLabel(nextQuality)}',
                    excludeSemantics: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MinutesText(
                          next.minutes,
                          color: nextQuality == ArrivalQuality.scheduled
                              ? tokens.softText
                              : tokens.strongText,
                        ),
                        const SizedBox(height: 6),
                        // Fontes maiores (acessibilidade) reduzem o selo em vez
                        // de empurrar a linha para fora da tela.
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: QualityBadge(nextQuality),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.xs),
                  VehicleTrackBox(
                    arrival: next,
                    tracking: tracking,
                    onTrack: onTrack,
                  ),
                ],
              ),
            ),
            if (following != null && canTrack(following)) ...[
              const SizedBox(height: Space.xs),
              _FollowingStrip(
                arrival: following,
                tracking: tracking,
                onTrack: onTrack,
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isTracked(Arrival? arrival) {
    final number = arrival?.vehicleNumber;
    return number != null && tracking?.vehicleNumber == number;
  }
}

/// Chegada seguinte com GPS: também pode ser acompanhada.
class _FollowingStrip extends StatelessWidget {
  const _FollowingStrip({
    required this.arrival,
    required this.tracking,
    required this.onTrack,
  });

  final Arrival arrival;
  final TrackingInfo? tracking;
  final ValueChanged<String> onTrack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
      decoration: BoxDecoration(
        color: tokens.raised.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.plate),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              label:
                  'Seguinte: ${minutesSemantics(arrival.minutes)}, '
                  '${qualityLabel(displayQuality(arrival))}, '
                  'ônibus ${arrival.vehicleNumber}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Text(
                    'SEGUINTE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: tokens.mutedText,
                    ),
                  ),
                  const SizedBox(width: Space.xs),
                  MinutesText(arrival.minutes, size: 15),
                  const SizedBox(width: Space.xs),
                  Flexible(child: QualityBadge(displayQuality(arrival))),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: VehicleTrackBox(
              arrival: arrival,
              tracking: tracking,
              onTrack: onTrack,
              horizontal: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Caixa com o número do ônibus que inicia o acompanhamento. Desabilitada
/// (com "—") quando a chegada não tem GPS nem identidade de veículo.
class VehicleTrackBox extends StatelessWidget {
  const VehicleTrackBox({
    required this.arrival,
    required this.tracking,
    required this.onTrack,
    this.horizontal = false,
    super.key,
  });

  final Arrival arrival;
  final TrackingInfo? tracking;
  final ValueChanged<String> onTrack;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final number = arrival.vehicleNumber;
    final trackable = canTrack(arrival);
    final phase = trackable && tracking?.vehicleNumber == number
        ? tracking!.phase
        : null;

    if (!trackable) {
      return Semantics(
        container: true,
        label: 'Acompanhamento indisponível: chegada sem GPS da fonte',
        excludeSemantics: true,
        child: Opacity(
          opacity: 0.45,
          child: _frame(
            tokens,
            selected: false,
            children: [
              Text('—', style: _numberStyle(tokens)),
              Icon(
                Icons.my_location_rounded,
                size: 16,
                color: tokens.mutedText,
              ),
            ],
          ),
        ),
      );
    }

    final Widget icon = switch (phase) {
      null => Icon(
        Icons.my_location_rounded,
        size: 16,
        color: tokens.accentText,
      ),
      TrackingPhase.searching => SizedBox.square(
        dimension: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: tokens.accentText,
        ),
      ),
      TrackingPhase.active => Icon(
        Icons.directions_bus_rounded,
        size: 16,
        color: tokens.accentText,
      ),
      TrackingPhase.unavailable => Icon(
        Icons.location_disabled_rounded,
        size: 16,
        color: tokens.unconfirmed,
      ),
      TrackingPhase.failing => Icon(
        Icons.sync_problem_rounded,
        size: 16,
        color: tokens.unconfirmed,
      ),
    };
    final label = switch (phase) {
      null => 'Acompanhar ônibus $number',
      TrackingPhase.searching => 'Buscando posição do ônibus $number',
      TrackingPhase.active => 'Acompanhando ônibus $number',
      TrackingPhase.unavailable => 'Ônibus $number sem posição',
      TrackingPhase.failing => 'Reconectando ao ônibus $number',
    };

    return Tooltip(
      message: label,
      // O rótulo já está no nó do botão; sem isto o tooltip vaza para o nó
      // do cartão.
      excludeFromSemantics: true,
      child: Semantics(
        container: true,
        button: true,
        label: label,
        excludeSemantics: true,
        child: _frame(
          tokens,
          selected: phase != null,
          // Já acompanhado: tocar de novo força uma nova consulta (sem trocar
          // de ônibus), útil depois de uma falha.
          onTap: phase == TrackingPhase.searching
              ? null
              : () => onTrack(number!),
          children: [
            Text(number!, style: _numberStyle(tokens)),
            icon,
          ],
        ),
      ),
    );
  }

  TextStyle _numberStyle(BusaoTokens tokens) => monoStyle(
    TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: tokens.strongText,
      height: 1,
    ),
  );

  Widget _frame(
    BusaoTokens tokens, {
    required bool selected,
    required List<Widget> children,
    VoidCallback? onTap,
  }) {
    final content = horizontal
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [children[1], const SizedBox(width: 6), children[0]],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [children[0], const SizedBox(height: 5), children[1]],
          );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: horizontal ? null : 54,
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: selected ? tokens.accentSoft : tokens.background,
        borderRadius: BorderRadius.circular(Radii.plate),
        border: Border.all(
          color: selected ? tokens.accent : tokens.hairline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.plate),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontal ? Space.sm : 4,
              vertical: 6,
            ),
            child: Center(widthFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}
