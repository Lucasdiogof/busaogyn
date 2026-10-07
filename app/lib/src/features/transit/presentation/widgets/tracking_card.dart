import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../../domain/entities/arrival.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../cubit/stop_arrivals_cubit.dart';
import '../formatters/transit_labels.dart';

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

class TrackingCard extends StatelessWidget {
  const TrackingCard({
    required this.tracking,
    required this.arrivals,
    required this.onStop,
    required this.clock,
    super.key,
  });

  final TrackingInfo tracking;
  final List<ArrivalGroup> arrivals;
  final VoidCallback onStop;
  final DateTime Function() clock;

  /// Linha/destino do grupo de chegada, quando a posição ainda não trouxe.
  ArrivalGroup? get _group {
    for (final group in arrivals) {
      if (group.next.vehicleNumber == tracking.vehicleNumber ||
          group.following?.vehicleNumber == tracking.vehicleNumber) {
        return group;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final vehicle = tracking.vehicle?.data;
    final group = _group;
    final routeId = vehicle?.routeId ?? group?.routeId;
    final destination = vehicle?.destination ?? group?.destination;

    final (
      IconData icon,
      String label,
      PillTone tone,
    ) = switch (tracking.phase) {
      TrackingPhase.searching => (
        Icons.radar_rounded,
        'Buscando posição',
        PillTone.accent,
      ),
      TrackingPhase.active => (
        Icons.check_circle_rounded,
        'Acompanhando',
        PillTone.positive,
      ),
      TrackingPhase.unavailable => (
        Icons.location_disabled_rounded,
        'Posição indisponível',
        PillTone.caution,
      ),
      TrackingPhase.failing => (
        Icons.sync_problem_rounded,
        'Conexão instável',
        PillTone.caution,
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.sm,
        Space.xs,
        Space.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    liveRegion: true,
                    child: StatusPill(icon: icon, label: label, tone: tone),
                  ),
                ),
              ),
              IconButton(
                onPressed: onStop,
                tooltip: 'Parar de acompanhar',
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: Space.xs),
            child: Row(
              children: [
                if (routeId != null) ...[
                  RoutePlate(routeId, dense: true),
                  const SizedBox(width: Space.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ônibus ${tracking.vehicleNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (destination != null)
                        Text(
                          destination,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.mutedText,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                  tone: vehicle.accessible == true
                      ? PillTone.accent
                      : PillTone.neutral,
                ),
              ],
            ),
          ],
          // Sem nenhuma posição o pill do topo já diz o estado.
          if (tracking.vehicle != null) ...[
            const SizedBox(height: Space.sm),
            PeriodicRebuild(
              builder: (context) {
                final freshness = positionFreshness(tracking, clock());
                return _FreshnessLine(freshness);
              },
            ),
          ],
          if (tracking.phase == TrackingPhase.unavailable ||
              tracking.phase == TrackingPhase.failing) ...[
            const SizedBox(height: Space.xxs),
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: Text(
                [
                  ?tracking.message,
                  if (tracking.vehicle != null)
                    'O mapa mostra a última posição válida.',
                  'Nova tentativa automática a cada 15 s.',
                ].join(' '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.mutedText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _punctualityPill(VehiclePunctuality punctuality) {
    final (icon, tone) = switch (punctuality) {
      VehiclePunctuality.onTime => (Icons.timer_outlined, PillTone.positive),
      VehiclePunctuality.delayed => (Icons.more_time_rounded, PillTone.caution),
      VehiclePunctuality.early => (Icons.fast_forward_rounded, PillTone.accent),
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
    return Row(
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
    );
  }
}
