import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../../../catalog/presentation/catalog_access.dart';
import '../cubit/stop_arrivals_cubit.dart';
import 'arrival_card.dart';

/// Exemplo da intro; é um ponto real da RMTC, não um favorito.
const exampleStopId = '30402';

/// Conteúdo da aba Chegadas: intro, carregamento ou chegadas do ponto. Erros de
/// busca aparecem junto do campo (ver `SearchHeader`), não aqui.
class ArrivalsPanel extends StatelessWidget {
  const ArrivalsPanel({
    required this.state,
    required this.onRefresh,
    required this.onTrack,
    required this.onOpenTracking,
    required this.onExample,
    this.onRetrySearch,
    this.above,
    this.below,
    super.key,
  });

  final StopArrivalsState state;
  final VoidCallback onRefresh;
  final ValueChanged<String> onTrack;
  final VoidCallback onOpenTracking;
  final ValueChanged<String> onExample;

  /// Repete a última busca que falhou por conexão ou fonte.
  final VoidCallback? onRetrySearch;

  /// Conteúdo extra no fim do painel (v2: Recentes). `null` no dock atual.
  final Widget? below;

  /// Dados do ponto no catálogo oficial, acima das chegadas (só com o ponto
  /// carregado). `null` com o catálogo desligado.
  final Widget? above;

  @override
  Widget build(BuildContext context) {
    final children = switch (state) {
      StopArrivalsInitial(:final searchError?)
          when searchError.isConnectivity =>
        [_ConnectionProblem(feedback: searchError, onRetry: onRetrySearch)],
      StopArrivalsInitial() => [
        if (above != null) ...[above!, const SizedBox(height: Space.md)],
        _Intro(onExample: onExample),
      ],
      StopArrivalsLoading(:final stopId) => [_LoadingView(stopId: stopId)],
      final StopArrivalsLoaded loaded => _loaded(context, loaded),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...children,
        if (below != null && state is! StopArrivalsLoading) below!,
      ],
    );
  }

  List<Widget> _loaded(BuildContext context, StopArrivalsLoaded state) {
    final tokens = context.tokens;
    final arrivals = state.arrivals.data;
    final tracking = state.tracking;

    return [
      if (above != null) ...[above!, const SizedBox(height: Space.sm)],
      if (tracking != null) ...[
        _TrackingBanner(tracking: tracking, onOpen: onOpenTracking),
        const SizedBox(height: Space.sm),
      ],
      SectionLabel(
        icon: Icons.schedule_rounded,
        label: l10n.nextBuses,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.linesCount(arrivals.length),
              style: monoStyle(
                TextStyle(fontSize: 12, color: tokens.mutedText),
              ),
            ),
            const SizedBox(width: Space.xxs),
            // 48 dp: alvo mínimo de toque do Android.
            SizedBox.square(
              dimension: 48,
              child: IconButton(
                onPressed: state.refreshing ? null : onRefresh,
                tooltip: l10n.refreshArrivals,
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: state.refreshing
                    ? const BusaoLoader(size: 16)
                    : const Icon(Icons.refresh_rounded),
              ),
            ),
          ],
        ),
      ),
      if (state.refreshError != null) ...[
        const SizedBox(height: Space.xs),
        _InlineNotice(
          icon: Icons.sync_problem_rounded,
          text: _refreshFailed(state.arrivalsReceivedAt, state.refreshError!),
        ),
      ],
      if (state.arrivals.stale) ...[
        const SizedBox(height: Space.xs),
        _InlineNotice(
          icon: Icons.warning_amber_rounded,
          text: l10n.sourceUnstable,
        ),
      ],
      const SizedBox(height: Space.xs),
      if (arrivals.isEmpty)
        MessageView(
          icon: Icons.departure_board_rounded,
          title: l10n.noArrivalsNow,
          body: l10n.noArrivalsBody,
          action: OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.refresh),
          ),
        )
      else
        for (final group in arrivals) ...[
          ArrivalCard(
            group: group,
            tracking: tracking,
            onTrack: onTrack,
            stopId: state.stopId,
          ),
          const SizedBox(height: Space.xs),
        ],
      const SizedBox(height: Space.xxs),
      FootNote(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: l10n.qualityRealtime,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: '${l10n.legendRealtime} '),
              TextSpan(
                text: l10n.qualityScheduled,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: l10n.legendScheduled),
            ],
          ),
        ),
      ),
    ];
  }
}

/// Lembra que há um ônibus acompanhado e leva à aba Meu ônibus.
class _TrackingBanner extends StatelessWidget {
  const _TrackingBanner({required this.tracking, required this.onOpen});

  final TrackingInfo tracking;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      container: true,
      button: true,
      label: l10n.trackingBannerSemantics(tracking.vehicleNumber),
      excludeSemantics: true,
      child: Material(
        color: tokens.accentSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: tokens.accent),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.sm, 10, Space.xs, 10),
            child: Row(
              children: [
                Icon(
                  Icons.directions_bus_rounded,
                  size: 20,
                  color: tokens.accentText,
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${l10n.dockTracking} · '),
                        TextSpan(
                          text: tracking.vehicleNumber,
                          style: monoStyle(
                            const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: tokens.strongText,
                    ),
                  ),
                ),
                Text(
                  l10n.view,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.strongText,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: tokens.strongText),
              ],
            ),
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(Radii.plate),
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

/// Aviso de atualização que falhou, com a hora da última consulta bem-sucedida
/// quando houver.
String _refreshFailed(DateTime? at, String error) {
  if (at == null) return l10n.refreshFailedPrevious(error);
  final h = at.hour.toString().padLeft(2, '0');
  final m = at.minute.toString().padLeft(2, '0');
  return l10n.refreshFailedAt('$h:$m', error);
}

/// Busca que falhou por conexão ou pela fonte: nada de previsão antiga como
/// se fosse atual. Explica o que continua funcionando e oferece tentar de
/// novo, uma consulta por toque.
class _ConnectionProblem extends StatelessWidget {
  const _ConnectionProblem({required this.feedback, required this.onRetry});

  final SearchFeedback feedback;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = feedback.kind == SearchFeedbackKind.offline;
    final code = feedback.stopId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MessageView(
          icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
          title: offline ? l10n.connOfflineTitle : l10n.connFailedTitle,
          body: offline
              ? l10n.connOfflineBody
              : (code == null
                    ? l10n.connFailedBodyNoCode
                    : l10n.connFailedBody(code)),
          action: onRetry == null
              ? null
              : OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(code == null ? l10n.retry : l10n.retryStop(code)),
                ),
        ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onExample});

  final ValueChanged<String> onExample;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MessageView(
          icon: Icons.location_on_outlined,
          // Com o catálogo oficial ligado, a busca aceita rua, bairro e cidade.
          title: context.catalog == null
              ? l10n.introTitle
              : l10n.catalogIntroTitle,
          body: context.catalog == null
              ? l10n.introBody
              : l10n.catalogIntroBody,
          action: Semantics(
            button: true,
            label: l10n.exampleStopSemantics(exampleStopId),
            excludeSemantics: true,
            child: ActionChip(
              onPressed: () => onExample(exampleStopId),
              avatar: Icon(
                Icons.north_east_rounded,
                size: 16,
                color: tokens.accentText,
              ),
              label: Text(
                l10n.exampleStop(exampleStopId),
                style: monoStyle(
                  TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.strongText,
                  ),
                ),
              ),
              backgroundColor: tokens.card,
              side: BorderSide(color: tokens.hairline),
              shape: const StadiumBorder(),
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        FootNote(child: Text(l10n.introNote)),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.stopId});

  final String? stopId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget row() => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: tokens.hairline),
      ),
      child: const Row(
        children: [
          SkeletonBlock(height: 44, width: 52, radius: Radii.plate),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(height: 14),
                SizedBox(height: 6),
                SkeletonBlock(height: 10, width: 80),
              ],
            ),
          ),
          SizedBox(width: Space.sm),
          SkeletonBlock(height: 48, width: 58, radius: Radii.plate),
        ],
      ),
    );

    return Semantics(
      liveRegion: true,
      label: l10n.queryingArrivalsSemantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            icon: Icons.schedule_rounded,
            label: stopId == null
                ? l10n.favoriteStatusLoading
                : l10n.queryingStop(stopId!),
          ),
          const SizedBox(height: Space.sm),
          row(),
          const SizedBox(height: Space.xs),
          row(),
          const SizedBox(height: Space.xs),
          row(),
        ],
      ),
    );
  }
}
