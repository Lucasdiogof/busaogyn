import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/settings/theme_mode_cubit.dart';
import '../../../../core/theme/busao_tokens.dart';

/// Aba Ajustes: tema e informações sobre as fontes de dados do app.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GroupLabel('Aparência'),
        _Tile(
          title: 'Tema',
          body: 'O mapa acompanha o tema escolhido.',
          below: BlocBuilder<ThemeModeCubit, ThemeMode>(
            builder: (context, mode) => SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: _SegmentLabel('Sistema'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: _SegmentLabel('Noturno'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: _SegmentLabel('Claro'),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) =>
                    context.read<ThemeModeCubit>().select(selection.first),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        const _GroupLabel('Sobre'),
        const _Tile(
          title: 'Dados de ônibus',
          body:
              'RMTC, via API BusãoGyn. Posições e previsões em tempo real '
              'dependem do GPS informado pela fonte.',
        ),
        const SizedBox(height: Space.xs),
        const _Tile(
          title: 'Mapa',
          body: 'OpenFreeMap · © OpenMapTiles · dados © OpenStreetMap',
        ),
        const SizedBox(height: Space.xs),
        const _Tile(
          title: 'Tipografia',
          body: 'Geist e Geist Mono · SIL Open Font License 1.1',
        ),
        const SizedBox(height: Space.xs),
        _Tile(
          title: 'Licenças',
          body: 'Bibliotecas e fontes usadas pelo app.',
          onTap: () =>
              showLicensePage(context: context, applicationName: 'BusãoGyn'),
        ),
      ],
    );
  }
}

/// Rótulo de uma opção de tema numa linha só: com fonte grande ele reduz
/// para caber no segmento em vez de partir a palavra ("Sistem/a").
class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xxs, 0, 0, Space.xs),
      child: Semantics(
        container: true,
        header: true,
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: context.tokens.mutedText,
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.body,
    this.below,
    this.onTap,
  });

  final String title;
  final String body;
  final Widget? below;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      container: true,
      child: Material(
        color: tokens.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: tokens.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: tokens.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: tokens.mutedText,
                      ),
                  ],
                ),
                if (below != null) ...[
                  const SizedBox(height: Space.sm),
                  below!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
