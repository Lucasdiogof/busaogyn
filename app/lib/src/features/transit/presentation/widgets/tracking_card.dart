import 'package:flutter/material.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../../domain/entities/arrival.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../cubit/stop_arrivals_cubit.dart';
import '../formatters/transit_labels.dart';
import 'arrival_card.dart';
import 'map_follow_controller.dart';

/// Conteúdo da aba Meu ônibus: onde está o ônibus escolhido.
class TrackingCard extends StatelessWidget {
  const TrackingCard({
    required this.state,
    required this.tracking,
    required this.onStop,
    required this.clock,
    this.followController,
    super.key,
  });

  /// Ponto consultado; dá a previsão de chegada do ônibus acompanhado.
  final StopArrivalsLoaded state;
  final TrackingInfo tracking;
  final VoidCallback onStop;
  final DateTime Function() clock;
  final MapFollowController? followController;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final vehicle = tracking.vehicle?.data;
    final match = trackedArrival(state.arrivals.data, tracking.vehicleNumber);
    final routeId = vehicle?.routeId ?? match?.group.routeId;
    final destination = vehicle?.destination ?? match?.group.destination;

    final (IconData icon, String label, Color color) = switch (tracking.phase) {
      TrackingPhase.searching => (
        Icons.radar_rounded,
        'Buscando posição',
        tokens.softText,
      ),
      TrackingPhase.active => (
        Icons.check_circle_outline_rounded,
        'Acompanhando',
        tokens.accentText,
      ),
      TrackingPhase.unavailable => (
        Icons.location_disabled_rounded,
        'Posição indisponível',
        tokens.unconfirmed,
      ),
      TrackingPhase.failing => (
        Icons.sync_problem_rounded,
        'Conexão instável',
        tokens.unconfirmed,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
          child: Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Semantics(
                  liveRegion: true,
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
              PeriodicRebuild(
                builder: (context) {
                  final age = positionAgeLabel(tracking, clock());
                  if (age == null) return const SizedBox.shrink();
                  return Text(
                    age,
                    style: monoStyle(
                      TextStyle(fontSize: 11.5, color: tokens.mutedText),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        _Identity(
          vehicleNumber: tracking.vehicleNumber,
          routeId: routeId,
          destination: destination,
        ),
        const SizedBox(height: Space.sm),
        _Eta(state: state, match: match, clock: clock),
        if (vehicle != null) ...[
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              _punctualityPill(vehicle.punctuality),
              StatusPill(
                icon: vehicle.accessible == true
                    ? Icons.accessible_rounded
                    : Icons.accessibility_new_rounded,
                label: accessibilityLabel(vehicle.accessible),
              ),
            ],
          ),
        ],
        // Sem nenhuma posição o título já diz o estado.
        if (tracking.vehicle != null) ...[
          const SizedBox(height: Space.sm),
          PeriodicRebuild(
            builder: (context) =>
                _FreshnessLine(positionFreshness(tracking, clock())),
          ),
        ],
        if (tracking.phase == TrackingPhase.unavailable ||
            tracking.phase == TrackingPhase.failing) ...[
          const SizedBox(height: Space.xxs),
          Text(
            [
              ?tracking.message,
              if (tracking.vehicle != null)
                'O mapa mostra a última posição válida.',
              'Nova tentativa automática a cada 15 s.',
            ].join(' '),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.mutedText),
          ),
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

class _FreshnessLine extends StatelessWidget {
  const _FreshnessLine(this.freshness);

  final Freshness freshness;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (icon, color) = switch (freshness.tone) {
      FreshnessTone.fresh => (Icons.bolt_rounded, tokens.realtime),
      FreshnessTone.aging => (Icons.history_rounded, tokens.mutedText),
      FreshnessTone.stale => (Icons.warning_amber_rounded, tokens.unconfirmed),
      FreshnessTone.unavailable => (
        Icons.location_disabled_rounded,
        tokens.unconfirmed,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: Space.xxs),
          Expanded(
            child: Text(
              freshness.text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
