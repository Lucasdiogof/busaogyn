import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/busao_tokens.dart';
import '../../../../core/ui/busao_components.dart';
import '../../domain/saved_stop.dart';
import '../cubit/saved_stops_cubit.dart';

/// Estrela do cabeçalho do ponto: preenchida quando o ponto é favorito. O
/// estado muda de forma (estrela cheia ou só contorno), não só de cor.
class FavoriteToggleButton extends StatelessWidget {
  const FavoriteToggleButton({
    required this.code,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final String code;

  /// Só há o que favoritar com um ponto já consultado.
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SavedStopsCubit, SavedStopsState, bool>(
      selector: (state) => state.isFavorite(code),
      builder: (context, favorite) {
        final tooltip = favorite
            ? 'Remover o ponto $code dos favoritos'
            : 'Favoritar o ponto $code';
        // Alvo de toque de 48 dp (o tema padrão dos botões de ícone é 44).
        return SizedBox.square(
          dimension: 48,
          child: IconButton(
            tooltip: tooltip,
            isSelected: favorite,
            onPressed: enabled ? onPressed : null,
            icon: const Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(
              Icons.star_rounded,
              color: context.tokens.accentText,
            ),
          ),
        );
      },
    );
  }
}

/// Aviso curto dentro das listas.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

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

/// Avisos sobre o armazenamento: não guarda, não leu, não gravou.
class _StorageNotices extends StatelessWidget {
  const _StorageNotices({required this.state});

  final SavedStopsState state;

  @override
  Widget build(BuildContext context) {
    final notices = <(IconData, String)>[
      if (!state.persistent)
        (
          Icons.save_outlined,
          'Este aparelho não guardou os pontos. Eles valem só até fechar o app.',
        ),
      if (state.readFailed)
        (
          Icons.sync_problem_rounded,
          'Não foi possível ler os pontos salvos. Começamos com a lista vazia.',
        ),
      if (state.writeFailed)
        (
          Icons.sync_problem_rounded,
          'Não foi possível salvar agora. A lista vale até fechar o app.',
        ),
    ];
    if (notices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (icon, text) in notices) ...[
          _Notice(icon: icon, text: text),
          const SizedBox(height: Space.xs),
        ],
      ],
    );
  }
}

/// Linha de um ponto guardado: toque consulta o ponto; o botão da direita
/// remove. Toda a linha e o botão têm pelo menos 48 dp.
class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.stop,
    required this.icon,
    required this.removeTooltip,
    required this.onOpen,
    required this.onRemove,
  });

  final SavedStop stop;
  final IconData icon;
  final String removeTooltip;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final named = stop.name != null;
    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: tokens.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label:
                  'Consultar as chegadas do ponto ${stop.code}'
                  '${named ? ', ${stop.name}' : ''}',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.card),
                onTap: onOpen,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.sm,
                      Space.xs,
                      Space.xs,
                      Space.xs,
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: tokens.accentText),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (named)
                                Text(
                                  stop.name!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: tokens.strongText,
                                  ),
                                ),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Ponto ',
                                      style: TextStyle(
                                        fontWeight: named
                                            ? FontWeight.w400
                                            : FontWeight.w600,
                                        color: named
                                            ? tokens.mutedText
                                            : tokens.strongText,
                                      ),
                                    ),
                                    TextSpan(
                                      text: stop.code,
                                      style: monoStyle(
                                        TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: named
                                              ? tokens.mutedText
                                              : tokens.strongText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox.square(
            dimension: 48,
            child: IconButton(
              tooltip: removeTooltip,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

const _offlineHint =
    'Toque num ponto para consultar as chegadas. A consulta precisa de '
    'internet e nenhuma previsão fica salva no aparelho.';

/// Aba Favoritos: os pontos favoritos, ou um estado vazio claro. Funciona sem
/// internet; só a consulta de chegadas precisa de conexão.
class FavoritesPanel extends StatelessWidget {
  const FavoritesPanel({
    required this.onOpen,
    required this.onSearchStop,
    this.connectionNotice,
    super.key,
  });

  /// Consulta o ponto (abre Pontos).
  final ValueChanged<String> onOpen;

  /// Leva à busca de pontos.
  final VoidCallback onSearchStop;

  /// Aviso quando a última consulta falhou por conexão ou fonte.
  final String? connectionNotice;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavedStopsCubit, SavedStopsState>(
      builder: (context, state) {
        final children = <Widget>[
          _StorageNotices(state: state),
          if (connectionNotice != null) ...[
            _Notice(icon: Icons.wifi_off_rounded, text: connectionNotice!),
            const SizedBox(height: Space.xs),
          ],
        ];
        if (state.loading) {
          children.add(const _LoadingRows());
        } else if (state.favorites.isEmpty) {
          children.add(
            MessageView(
              icon: Icons.star_outline_rounded,
              title: 'Seus pontos favoritos aparecerão aqui.',
              body:
                  'Consulte um ponto e toque na estrela do cabeçalho para '
                  'favoritá-lo.',
              action: FilledButton.icon(
                onPressed: onSearchStop,
                icon: const Icon(Icons.location_on_outlined, size: 20),
                label: const Text('Buscar um ponto'),
              ),
            ),
          );
        } else {
          children
            ..add(
              SectionLabel(
                icon: Icons.star_rounded,
                label: 'Pontos favoritos',
                trailing: Text(
                  '${state.favorites.length}',
                  style: monoStyle(
                    TextStyle(fontSize: 12, color: context.tokens.mutedText),
                  ),
                ),
              ),
            )
            ..add(const SizedBox(height: Space.xs));
          for (final stop in state.favorites) {
            children
              ..add(
                _StopTile(
                  stop: stop,
                  icon: Icons.star_rounded,
                  removeTooltip: 'Remover o ponto ${stop.code} dos favoritos',
                  onOpen: () => onOpen(stop.code),
                  onRemove: () =>
                      context.read<SavedStopsCubit>().removeFavorite(stop.code),
                ),
              )
              ..add(const SizedBox(height: Space.xs));
          }
          children.add(const FootNote(child: Text(_offlineHint)));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

/// Seção Recentes da aba Pontos: os últimos pontos consultados com sucesso.
class RecentStopsSection extends StatelessWidget {
  const RecentStopsSection({
    required this.onOpen,
    this.excludeCode,
    this.showEmpty = false,
    this.connectionNotice,
    super.key,
  });

  /// Consulta o ponto de novo.
  final ValueChanged<String> onOpen;

  /// Ponto que já está na tela (não repete na lista).
  final String? excludeCode;

  /// Mostra a seção mesmo sem itens (explicando que está vazia).
  final bool showEmpty;
  final String? connectionNotice;

  Future<void> _confirmClear(BuildContext context) async {
    final cubit = context.read<SavedStopsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar recentes?'),
        content: const Text(
          'O histórico de pontos consultados neste aparelho será apagado. '
          'Seus favoritos não mudam.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.clearRecents();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SavedStopsCubit, SavedStopsState>(
      builder: (context, state) {
        final recents = [
          for (final stop in state.recents)
            if (stop.code != excludeCode) stop,
        ];
        if (!state.loading && recents.isEmpty && !showEmpty) {
          return const SizedBox.shrink();
        }
        final tokens = context.tokens;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Space.md),
            SectionLabel(
              icon: Icons.history_rounded,
              label: 'Recentes',
              trailing: recents.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => _confirmClear(context),
                      child: const Text('Limpar'),
                    ),
            ),
            const SizedBox(height: Space.xs),
            _StorageNotices(state: state),
            if (connectionNotice != null) ...[
              _Notice(icon: Icons.wifi_off_rounded, text: connectionNotice!),
              const SizedBox(height: Space.xs),
            ],
            if (state.loading)
              const _LoadingRows(count: 1)
            else if (recents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.xxs,
                  vertical: Space.xs,
                ),
                child: Text(
                  'Os pontos que você consultar aparecerão aqui.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.mutedText),
                ),
              )
            else ...[
              for (final stop in recents) ...[
                _StopTile(
                  stop: stop,
                  icon: Icons.history_rounded,
                  removeTooltip: 'Remover o ponto ${stop.code} dos recentes',
                  onOpen: () => onOpen(stop.code),
                  onRemove: () =>
                      context.read<SavedStopsCubit>().removeRecent(stop.code),
                ),
                const SizedBox(height: Space.xs),
              ],
              const FootNote(child: Text(_offlineHint)),
            ],
          ],
        );
      },
    );
  }
}

class _LoadingRows extends StatelessWidget {
  const _LoadingRows({this.count = 2});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando pontos salvos',
      child: Column(
        children: [
          for (var i = 0; i < count; i++) ...[
            const SkeletonBlock(height: 56, width: double.infinity, radius: 16),
            const SizedBox(height: Space.xs),
          ],
        ],
      ),
    );
  }
}
