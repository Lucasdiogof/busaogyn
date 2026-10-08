import 'package:flutter/material.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../../domain/entities/arrival.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../cubit/stop_arrivals_cubit.dart';
import '../formatters/transit_labels.dart';
import 'arrival_card.dart';
import 'map_follow_controller.dart';

/// Conteúdo da aba Meu ônibus: a ficha do ônibus acompanhado. O compacto
/// traz o essencial (estado da posição, linha, destino, previsão); os
/// detalhes abrem sob demanda. Só mostra dados que a fonte informou.
class TrackingCard extends StatelessWidget {
  const TrackingCard({
    required this.state,
    required this.tracking,
    required this.onStop,
    required this.clock,
    this.followController,
    this.detailsExpanded = false,
    this.onToggleDetails,
    super.key,
  });

  /// Ponto consultado; dá a previsão de chegada do ônibus acompanhado.
  final StopArrivalsLoaded state;
  final TrackingInfo tracking;
  final VoidCallback onStop;
  final DateTime Function() clock;
  final MapFollowController? followController;
  final bool detailsExpanded;
  final VoidCallback? onToggleDetails;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final vehicle = tracking.vehicle?.data;
    final match = trackedArrival(state.arrivals.data, tracking.vehicleNumber);
    final routeId = vehicle?.routeId ?? match?.group.routeId;
    final destination = vehicle?.destination ?? match?.group.destination;

    final searching = tracking.phase == TrackingPhase.searching;
    final status = [
      Icon(
        searching ? Icons.radar_rounded : Icons.check_circle_outline_rounded,
        size: 17,
        color: searching ? tokens.softText : tokens.accentText,
      ),
      const SizedBox(width: Space.xs),
      Expanded(
        child: Text(
          (searching ? 'Buscando posição' : 'Acompanhando').toUpperCase(),
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
    ];
    final age = PeriodicRebuild(
      builder: (context) {
        final age = positionAgeLabel(tracking, clock());
        if (age == null) return const SizedBox.shrink();
        return Text(
          age,
          style: monoStyle(TextStyle(fontSize: 11.5, color: tokens.mutedText)),
        );
      },
    );
    // Com fonte grande (150%+) a idade da posição desce para baixo do
    // estado em vez de disputar a mesma linha e estourar a largura.
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final pills = vehicle == null ? const <Widget>[] : _pills(vehicle);
    final notice = _positionNotice(hasEta: match?.arrival != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: status),
                    age,
                  ],
                )
              : Row(children: [...status, age]),
        ),
        const SizedBox(height: Space.sm),
        _Identity(
          vehicleNumber: tracking.vehicleNumber,
          routeId: routeId,
          destination: destination,
        ),
        const SizedBox(height: Space.xs),
        PeriodicRebuild(
          builder: (context) =>
              _PositionLine(positionStatus(tracking, clock())),
        ),
        if (notice != null) ...[
          const SizedBox(height: Space.xxs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
            child: Text(
              notice,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.mutedText),
            ),
          ),
        ],
        const SizedBox(height: Space.sm),
        _Eta(state: state, match: match, clock: clock),
        if (pills.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Wrap(spacing: Space.xs, runSpacing: Space.xs, children: pills),
        ],
        const SizedBox(height: Space.sm),
        Row(
          children: [
            Expanded(child: _CenterButton(controller: followController)),
            const SizedBox(width: Space.xs),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Parar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        _DetailsToggle(expanded: detailsExpanded, onTap: onToggleDetails),
        if (detailsExpanded) ...[
          const SizedBox(height: Space.xs),
          _VehicleDetails(
            state: state,
            tracking: tracking,
            routeId: routeId,
            destination: destination,
            clock: clock,
          ),
        ],
        const SizedBox(height: Space.sm),
        const FootNote(
          child: Text(
            'Posição informada pela RMTC, consultada a cada 15 s. Direção '
            'baseada no deslocamento observado; o rastro mostra só posições '
            'recebidas.',
          ),
        ),
      ],
    );
  }

  /// Explica o estado da posição sem tratar como erro fatal: linha, destino
  /// e previsão continuam valendo.
  String? _positionNotice({required bool hasEta}) {
    final hasPosition = tracking.vehicle?.data?.position != null;
    final lastKnown = hasPosition
        ? ' O mapa mostra a última posição conhecida.'
        : '';
    return switch (tracking.phase) {
      TrackingPhase.unavailable =>
        '${hasEta ? 'A previsão de chegada continua disponível. ' : ''}'
            'Tentando localizar o ônibus novamente.$lastKnown',
      TrackingPhase.failing =>
        '${tracking.message ?? 'Falha temporária ao consultar a posição.'} '
            'Nova tentativa automática a cada 15 s.$lastKnown',
      _ => null,
    };
  }

  /// Só selos com dado real: pontualidade conhecida e acessibilidade
  /// confirmada. Ausência não vira selo.
  List<Widget> _pills(TrackedVehicle vehicle) {
    return [
      if (vehicle.punctuality != VehiclePunctuality.unknown)
        _punctualityPill(vehicle.punctuality),
      if (vehicle.accessible == true)
        StatusPill(
          icon: Icons.accessible_rounded,
          label: accessibilityLabel(true),
        ),
    ];
  }

  Widget _punctualityPill(VehiclePunctuality punctuality) {
    final (icon, tone) = switch (punctuality) {
      VehiclePunctuality.onTime => (Icons.timer_outlined, PillTone.positive),
      VehiclePunctuality.delayed => (Icons.more_time_rounded, PillTone.caution),
      VehiclePunctuality.early => (
        Icons.fast_forward_rounded,
        PillTone.neutral,
      ),
      VehiclePunctuality.unknown => (
        Icons.timer_off_outlined,
        PillTone.neutral,
      ),
    };
    return StatusPill(
      icon: icon,
      label: punctualityLabel(punctuality),
      tone: tone,
    );
  }
}

/// Estado da posição em destaque, com ícone e texto (não só cor).
class _PositionLine extends StatelessWidget {
  const _PositionLine(this.status);

  final PositionStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (icon, color) = switch (status.state) {
      PositionState.live => (Icons.sensors_rounded, tokens.realtime),
      PositionState.searching => (Icons.radar_rounded, tokens.softText),
      PositionState.aging => (Icons.history_rounded, tokens.mutedText),
      PositionState.stale => (
        Icons.history_toggle_off_rounded,
        tokens.unconfirmed,
      ),
      PositionState.unavailable => (
        Icons.location_searching_rounded,
        tokens.unconfirmed,
      ),
      PositionState.connection => (
        Icons.sync_problem_rounded,
        tokens.unconfirmed,
      ),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Posição do ônibus: ${status.text}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: Space.xxs),
            Expanded(
              child: Text(
                status.text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre e fecha os detalhes do ônibus.
class _DetailsToggle extends StatelessWidget {
  const _DetailsToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      expanded: expanded,
      label: expanded
          ? 'Detalhes do ônibus. Recolher'
          : 'Detalhes do ônibus. Expandir',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.plate),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: tokens.accentText,
                  ),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      'Detalhes do ônibus',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.strongText,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: tokens.softText,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ficha completa do ônibus acompanhado. Cada linha mostra o que a fonte
/// informou ou diz explicitamente que não há o dado; nada é estimado.
class _VehicleDetails extends StatelessWidget {
  const _VehicleDetails({
    required this.state,
    required this.tracking,
    required this.routeId,
    required this.destination,
    required this.clock,
  });

  final StopArrivalsLoaded state;
  final TrackingInfo tracking;
  final String? routeId;
  final String? destination;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final vehicle = tracking.vehicle?.data;
    final routeName = vehicle?.routeName?.trim();
    final punctuality = vehicle?.punctuality ?? VehiclePunctuality.unknown;
    final heading = tracking.movement.observedHeading;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.sm,
          Space.xs,
          Space.sm,
          Space.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailRow('Ônibus', tracking.vehicleNumber, mono: true),
            _DetailRow(
              'Linha',
              routeId ?? 'Não informada',
              secondary: routeName == null || routeName.isEmpty
                  ? null
                  : routeName,
              missing: routeId == null,
            ),
            _DetailRow(
              'Destino',
              destination == null
                  ? 'Não informado'
                  : destinationLabel(destination!),
              missing: destination == null,
            ),
            _DetailRow('Ponto de referência', 'Ponto ${state.stopId}'),
            PeriodicRebuild(
              builder: (context) =>
                  _DetailRow('Posição', positionStatus(tracking, clock()).text),
            ),
            _DetailRow(
              'Pontualidade',
              punctuality == VehiclePunctuality.unknown
                  ? 'Não informada'
                  : punctualityLabel(punctuality),
              missing: punctuality == VehiclePunctuality.unknown,
            ),
            _DetailRow('Acessibilidade', switch (vehicle?.accessible) {
              true => 'Acessível',
              false => 'Não indicada pela fonte',
              null => 'Não informada',
            }, missing: vehicle?.accessible != true),
            // A fonte ainda não informa lotação: nada é estimado.
            const _DetailRow(
              'Lotação',
              'Informação não disponível',
              missing: true,
            ),
            _DetailRow(
              'Movimento',
              heading == null
                  ? 'Direção ainda não observada'
                  : 'A seta no mapa indica a direção observada',
              missing: heading == null,
            ),
            const SizedBox(height: Space.xs),
            Text(
              'Rastro baseado nas posições observadas. Trajeto oficial ainda '
              'não disponível.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
    this.label,
    this.value, {
    this.secondary,
    this.missing = false,
    this.mono = false,
  });

  final String label;
  final String value;
  final String? secondary;

  /// Dado que a fonte não informou: texto neutro, sem destaque.
  final bool missing;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final valueStyle = TextStyle(
      fontSize: 14,
      fontWeight: missing ? FontWeight.w400 : FontWeight.w600,
      color: missing ? tokens.mutedText : tokens.strongText,
    );
    return Semantics(
      container: true,
      label: '$label: $value${secondary != null ? ', $secondary' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: tokens.mutedText),
            ),
            // Número do ônibus é identidade: nunca quebra em duas linhas.
            if (mono)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  style: monoStyle(valueStyle),
                ),
              )
            else
              Text(value, style: valueStyle),
            if (secondary != null)
              Text(
                secondary!,
                style: TextStyle(fontSize: 12.5, color: tokens.softText),
              ),
          ],
        ),
      ),
    );
  }
}

/// Quem é o ônibus: número, linha e para onde vai (só o que a fonte
/// informa).
class _Identity extends StatelessWidget {
  const _Identity({
    required this.vehicleNumber,
    required this.routeId,
    required this.destination,
  });

  final String vehicleNumber;
  final String? routeId;
  final String? destination;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      container: true,
      label:
          'Ônibus $vehicleNumber'
          '${routeId != null ? ', linha $routeId' : ''}'
          ', ${headingToLabel(destination)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // O número do ônibus já está no cabeçalho logo acima.
            Text(
              routeId != null ? 'Linha $routeId' : 'Linha não informada',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tokens.strongText,
              ),
            ),
            Text(
              headingToLabel(destination),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: destination == null
                    ? tokens.mutedText
                    : tokens.accentText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Previsão de chegada ao ponto, vinda da última consulta de chegadas (que
/// não é atualizada sozinha; por isso a idade aparece quando envelhece).
class _Eta extends StatelessWidget {
  const _Eta({required this.state, required this.match, required this.clock});

  final StopArrivalsLoaded state;
  final ({ArrivalGroup group, Arrival arrival})? match;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final match = this.match;
    if (match == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
        child: Text(
          'Previsão para o ponto ${state.stopId} indisponível.',
          style: TextStyle(fontSize: 14, color: tokens.softText),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              MinutesText(match.arrival.minutes, size: 30, unit: ''),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  match.arrival.minutes == null
                      ? 'previsão até o ponto ${state.stopId}'
                      : 'min até o ponto ${state.stopId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: tokens.softText),
                ),
              ),
            ],
          ),
          PeriodicRebuild(
            builder: (context) {
              final freshness = arrivalsFreshness(state, clock());
              if (freshness.tone == FreshnessTone.fresh) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Previsão da consulta do ponto · '
                  '${freshness.text.toLowerCase()}',
                  style: monoStyle(
                    TextStyle(
                      fontSize: 11,
                      color: freshness.tone == FreshnessTone.stale
                          ? tokens.unconfirmed
                          : tokens.mutedText,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({required this.controller});

  final MapFollowController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final enabled = controller.hasVehicle;
        final following = controller.following;
        return OutlinedButton.icon(
          onPressed: enabled ? controller.recenter : null,
          icon: Icon(
            following ? Icons.gps_fixed_rounded : Icons.my_location_rounded,
            size: 18,
          ),
          label: Text(following && enabled ? 'Seguindo' : 'Centralizar'),
        );
      },
    );
  }
}
