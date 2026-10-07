import 'package:flutter/material.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../cubit/stop_arrivals_cubit.dart';
import '../formatters/transit_labels.dart';
import 'arrival_card.dart';
import 'tracking_card.dart';

/// Conteúdo rolável do painel (bottom sheet no celular, lateral em telas
/// largas). [header] fica no topo da lista (alça do sheet, por exemplo).
class ArrivalsPanel extends StatelessWidget {
  const ArrivalsPanel({
    required this.state,
    required this.scrollController,
    required this.onRetry,
    required this.onRefresh,
    required this.onTrack,
    required this.onStopTracking,
    required this.clock,
    this.header,
    super.key,
  });

  final StopArrivalsState state;
  final ScrollController? scrollController;
  final ValueChanged<String?> onRetry;
  final VoidCallback onRefresh;
  final ValueChanged<String> onTrack;
  final VoidCallback onStopTracking;
  final DateTime Function() clock;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final children = switch (state) {
      StopArrivalsInitial() => const [_Intro()],
      StopArrivalsLoading(:final stopId) => [_LoadingView(stopId: stopId)],
      StopArrivalsFailure(:final message, :final stopId) => [
        MessageView(
          icon: Icons.cloud_off_rounded,
          tone: PillTone.danger,
          title: 'Não foi possível consultar',
          body: message,
          action: stopId == null
              ? null
              : OutlinedButton.icon(
                  onPressed: () => onRetry(stopId),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                ),
        ),
      ],
      final StopArrivalsLoaded loaded => _loaded(context, loaded),
    };

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        ?header,
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.xxs,
            Space.md,
            Space.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }

  List<Widget> _loaded(BuildContext context, StopArrivalsLoaded state) {
    final arrivals = state.arrivals.data;
    final tracking = state.tracking;

    return [
      _StopHeader(state: state, onRefresh: onRefresh, clock: clock),
      if (state.refreshError != null) ...[
        const SizedBox(height: Space.xs),
        _InlineNotice(
          icon: Icons.sync_problem_rounded,
          text:
              'Não foi possível atualizar agora. Mostrando a consulta '
              'anterior. ${state.refreshError}',
        ),
      ],
      if (state.arrivals.stale) ...[
        const SizedBox(height: Space.xs),
        const _InlineNotice(
          icon: Icons.warning_amber_rounded,
          text: 'A fonte está instável. Mostrando o último dado válido.',
        ),
      ],
      if (tracking != null) ...[
        const SizedBox(height: Space.sm),
        TrackingCard(
          tracking: tracking,
          arrivals: arrivals,
          onStop: onStopTracking,
          clock: clock,
        ),
      ],
      const SizedBox(height: Space.md),
      if (arrivals.isEmpty)
        MessageView(
          icon: Icons.departure_board_rounded,
          title: 'Nenhuma chegada prevista agora',
          body:
              'A fonte não informou ônibus para este ponto neste momento. '
              'Tente atualizar em alguns minutos.',
          action: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Atualizar'),
          ),
        )
      else ...[
        Text(
          arrivals.length == 1
              ? 'Próxima chegada · 1 linha'
              : 'Próximas chegadas · ${arrivals.length} linhas',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: context.tokens.mutedText),
        ),
        const SizedBox(height: Space.xs),
        for (final group in arrivals) ...[
          ArrivalCard(group: group, tracking: tracking, onTrack: onTrack),
          const SizedBox(height: Space.sm),
        ],
      ],
    ];
  }
}

class _StopHeader extends StatelessWidget {
  const _StopHeader({
    required this.state,
    required this.onRefresh,
    required this.clock,
  });

  final StopArrivalsLoaded state;
  final VoidCallback onRefresh;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ponto ${state.stopId}', style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              PeriodicRebuild(
                builder: (context) {
                  final freshness = arrivalsFreshness(state, clock());
                  final color = freshness.tone == FreshnessTone.stale
                      ? tokens.unconfirmed
                      : tokens.mutedText;
                  return Text(
                    state.refreshing ? 'Atualizando…' : freshness.text,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  );
                },
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: state.refreshing ? null : onRefresh,
          tooltip: 'Atualizar chegadas',
          icon: state.refreshing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: tokens.unconfirmedContainer,
        borderRadius: BorderRadius.circular(Radii.card - 4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tokens.unconfirmed),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.unconfirmed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    Widget step(IconData icon, String title, String body) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(Radii.chip + 2),
              ),
              child: Icon(icon, size: 20, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Onde está o seu ônibus?', style: theme.textTheme.titleLarge),
        const SizedBox(height: Space.xxs),
        Text(
          'Consulte um ponto pelo código RMTC, por exemplo 30402.',
          style: theme.textTheme.bodyMedium?.copyWith(color: tokens.mutedText),
        ),
        const SizedBox(height: Space.md),
        step(
          Icons.signpost_outlined,
          'Digite o código do ponto',
          'Veja as próximas chegadas de cada linha.',
        ),
        step(
          Icons.sensors_rounded,
          'Escolha uma chegada em tempo real',
          'Só ônibus com GPS informado pela fonte podem ser acompanhados.',
        ),
        step(
          Icons.map_outlined,
          'Acompanhe no mapa',
          'A posição informada pela RMTC é consultada a cada 15 s.',
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.stopId});

  final String? stopId;

  @override
  Widget build(BuildContext context) {
    Widget card() => const Card(
      child: Padding(
        padding: EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBlock(height: 30, width: 58),
                SizedBox(width: Space.sm),
                Expanded(child: SkeletonBlock(height: 16)),
              ],
            ),
            SizedBox(height: Space.md),
            SkeletonBlock(height: 26, width: 96),
            SizedBox(height: Space.xs),
            SkeletonBlock(height: 18, width: 140),
          ],
        ),
      ),
    );

    return Semantics(
      liveRegion: true,
      label: 'Consultando chegadas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stopId == null ? 'Consultando…' : 'Ponto $stopId',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            'Consultando chegadas…',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.tokens.mutedText),
          ),
          const SizedBox(height: Space.md),
          card(),
          const SizedBox(height: Space.sm),
          card(),
        ],
      ),
    );
  }
}
