import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/settings/theme_mode_cubit.dart';
import '../../../../core/theme/busao_tokens.dart';
import '../../../catalog/presentation/catalog_access.dart';

/// Aba Ajustes: tema e informações sobre as fontes de dados do app.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupLabel(l10n.settingsAppearance),
        _Tile(
          title: l10n.settingsTheme,
          body: l10n.settingsThemeBody,
          below: BlocBuilder<ThemeModeCubit, ThemeMode>(
            builder: (context, mode) => SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: _SegmentLabel(l10n.themeSystem),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: _SegmentLabel(l10n.themeNight),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: _SegmentLabel(l10n.themeLight),
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
        _GroupLabel(l10n.settingsAbout),
        _Tile(title: l10n.settingsBusData, body: l10n.settingsBusDataBody),
        if (context.catalog case final catalog?) ...[
          const SizedBox(height: Space.xs),
          _Tile(
            title: l10n.settingsCatalog,
            // Parâmetros em ordem alfabética (gen-l10n): license, reference,
            // version.
            body: l10n.settingsCatalogBody(
              catalog.version.licenseStatus,
              catalog.version.stopsReference ??
                  catalog.version.linesReference ??
                  '—',
              catalog.version.id,
            ),
          ),
        ],
        const SizedBox(height: Space.xs),
        _Tile(title: l10n.settingsMap, body: l10n.settingsMapBody),
        const SizedBox(height: Space.xs),
        _Tile(
          title: l10n.settingsTypography,
          body: l10n.settingsTypographyBody,
        ),
        const SizedBox(height: Space.xs),
        _Tile(
          title: l10n.settingsLicenses,
          body: l10n.settingsLicensesBody,
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
