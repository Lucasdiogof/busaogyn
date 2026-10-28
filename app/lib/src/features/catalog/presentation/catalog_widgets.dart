import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/busao_tokens.dart';
import '../../../core/ui/busao_components.dart';
import '../../saved_stops/domain/saved_stop.dart';
import '../../saved_stops/presentation/cubit/saved_stops_cubit.dart';
import '../../saved_stops/presentation/widgets/saved_stops_widgets.dart';
import '../domain/text_search.dart';
import '../domain/transit_catalog.dart';
import 'catalog_access.dart';

/// Quantos resultados de ponto aparecem de uma vez.
const catalogStopResultsLimit = 40;

/// Quantas linhas a lista do catálogo mostra antes de "Mostrar mais".
const catalogLinesPage = 60;

String _reference(TransitCatalog catalog) {
  final ref = catalog.version.stopsReference ?? catalog.version.linesReference;
  return ref ?? catalog.version.id;
}

/// Rodapé de proveniência: fonte oficial, data de referência, offline e o
/// aviso de que são dados de desenvolvimento (licença pendente).
class CatalogSourceNote extends StatelessWidget {
  const CatalogSourceNote({required this.catalog, super.key});

  final TransitCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return FootNote(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: l10n.catalogSourceNote(_reference(catalog))),
            if (catalog.version.restricted)
              TextSpan(
                text: ' · ${l10n.catalogDevBadge}',
                style: TextStyle(
                  color: tokens.unconfirmed,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Placas das linhas oficialmente associadas a um ponto.
class _LinePlates extends StatelessWidget {
  const _LinePlates(this.lineIds, {this.max});

  final List<String> lineIds;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final shown = max == null || lineIds.length <= max!
        ? lineIds
        : lineIds.take(max!).toList();
    final hidden = lineIds.length - shown.length;
    return Wrap(
      spacing: Space.xxs,
      runSpacing: Space.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // RoutePlate centraliza o número e, sem largura limitada, ocuparia a
        // linha inteira do Wrap.
        for (final id in shown)
          IntrinsicWidth(child: RoutePlate(id, dense: true)),
        if (hidden > 0)
          Text(
            '+$hidden',
            style: monoStyle(
              TextStyle(fontSize: 12, color: context.tokens.mutedText),
            ),
          ),
      ],
    );
  }
}

/// Um ponto do catálogo numa lista: código, endereço, bairro/município e
/// linhas. Toque abre os detalhes.
class CatalogStopTile extends StatelessWidget {
  const CatalogStopTile({required this.stop, required this.onTap, super.key});

  final CatalogStop stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final address = stop.address;
    final place = stop.place;
    return Semantics(
      button: true,
      label: l10n.catalogOpenStop(stop.id, [?address, ?place].join(', ')),
      excludeSemantics: true,
      child: Material(
        color: tokens.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: tokens.hairline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      stop.kind == CatalogStopKind.station
                          ? Icons.directions_transit_rounded
                          : Icons.location_on_outlined,
                      size: 20,
                      color: tokens.accentText,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address ?? l10n.catalogStation,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: tokens.strongText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: stop.id,
                                style: monoStyle(
                                  const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (place != null) TextSpan(text: ' · $place'),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.mutedText,
                          ),
                        ),
                        if (stop.lineIds.isNotEmpty) ...[
                          const SizedBox(height: Space.xs),
                          _LinePlates(stop.lineIds, max: 8),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: tokens.mutedText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resultados da busca de pontos no catálogo, enquanto o passageiro digita.
/// Busca 100% local: o texto não sai do aparelho.
class StopSearchResults extends StatelessWidget {
  const StopSearchResults({
    required this.catalog,
    required this.query,
    required this.onSelect,
    super.key,
  });

  final TransitCatalog catalog;
  final String query;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final all = catalog.rankStops(query, limit: 1 << 30);
    final shown = all.take(catalogStopResultsLimit).toList();
    final digits = RegExp(r'^\d+$').hasMatch(query.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          icon: Icons.manage_search_rounded,
          label: l10n.catalogResultsTitle,
          trailing: Text(
            l10n.catalogResultsCount(all.length),
            style: monoStyle(
              TextStyle(fontSize: 12, color: context.tokens.mutedText),
            ),
          ),
        ),
        const SizedBox(height: Space.xs),
        if (shown.isEmpty)
          MessageView(
            icon: Icons.search_off_rounded,
            title: l10n.catalogNoResultsTitle,
            body: digits ? l10n.catalogStopNotFound : l10n.catalogNoResultsBody,
          )
        else ...[
          if (digits) ...[
            FootNote(child: Text(l10n.catalogSearchCodeHint)),
            const SizedBox(height: Space.xs),
          ],
          for (final ranked in shown) ...[
            CatalogStopTile(
              key: ValueKey('catalog-stop-${ranked.item.id}'),
              stop: ranked.item,
              onTap: () => onSelect(ranked.item.id),
            ),
            const SizedBox(height: Space.xs),
          ],
          if (all.length > shown.length)
            FootNote(
              child: Text(l10n.catalogResultsMore(shown.length, all.length)),
            ),
        ],
        const SizedBox(height: Space.xs),
        CatalogSourceNote(catalog: catalog),
      ],
    );
  }
}

/// Bloco de dados oficiais de um ponto: endereço, bairro, município e linhas
/// que o atendem (cadastro, não previsão).
class CatalogStopFacts extends StatelessWidget {
  const CatalogStopFacts({
    required this.catalog,
    required this.stopId,
    this.compact = false,
    super.key,
  });

  final TransitCatalog catalog;
  final String stopId;

  /// Versão curta acima das chegadas.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final stop = catalog.stop(stopId);
    if (stop == null) {
      return Container(
        key: const ValueKey('catalog-stop-missing'),
        padding: const EdgeInsets.all(Space.sm),
        decoration: BoxDecoration(
          color: tokens.scheduledContainer,
          borderRadius: BorderRadius.circular(Radii.plate),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: tokens.scheduled),
            const SizedBox(width: Space.xs),
            Expanded(
              child: Text(
                l10n.catalogStopNotFound,
                style: TextStyle(fontSize: 13, color: tokens.softText),
              ),
            ),
          ],
        ),
      );
    }
    Widget fact(String label, String? value) => value == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: Space.xxs),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(color: tokens.mutedText),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(color: tokens.strongText),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 14, height: 1.3),
            ),
          );

    return Container(
      key: ValueKey('catalog-stop-facts-${stop.id}'),
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact)
            Text(
              stop.address ?? l10n.catalogStation,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.strongText,
              ),
            )
          else
            fact(l10n.catalogAddress, stop.address ?? l10n.catalogStation),
          if (compact)
            if (stop.place case final place?)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  place,
                  style: TextStyle(fontSize: 13, color: tokens.mutedText),
                ),
              )
            else
              const SizedBox.shrink()
          else ...[
            fact(
              l10n.catalogDistrict,
              stop.district == null ? null : displayCase(stop.district),
            ),
            fact(
              l10n.catalogCity,
              stop.city == null ? null : displayCase(stop.city),
            ),
          ],
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Icon(Icons.alt_route_rounded, size: 16, color: tokens.mutedText),
              const SizedBox(width: Space.xxs),
              Expanded(
                child: Text(
                  l10n.catalogStopLinesTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.softText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          if (stop.lineIds.isEmpty)
            Text(
              l10n.catalogNoLinesListed,
              style: TextStyle(fontSize: 13, color: tokens.mutedText),
            )
          else
            _LinePlates(stop.lineIds),
          const SizedBox(height: Space.xs),
          Text(
            l10n.catalogStopLinesNote,
            style: TextStyle(
              fontSize: 12,
              color: tokens.mutedText,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Detalhes de um ponto escolhido na busca ou na linha. Funciona offline;
/// só "Ver chegadas" precisa de internet.
class StopPreview extends StatelessWidget {
  const StopPreview({
    required this.catalog,
    required this.stopId,
    required this.onSeeArrivals,
    super.key,
  });

  final TransitCatalog catalog;
  final String stopId;
  final VoidCallback onSeeArrivals;

  Future<void> _toggleFavorite(BuildContext context) async {
    final result = await context.read<SavedStopsCubit>().toggleFavorite(stopId);
    if (!context.mounted || result != FavoriteResult.limitReached) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.favoriteStopsLimit(defaultFavoriteStopsLimit)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CatalogStopFacts(catalog: catalog, stopId: stopId),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('catalog-see-arrivals'),
                onPressed: onSeeArrivals,
                icon: const Icon(Icons.schedule_rounded, size: 20),
                label: Text(l10n.catalogSeeArrivals),
              ),
            ),
            const SizedBox(width: Space.xs),
            FavoriteToggleButton(
              code: stopId,
              enabled: true,
              onPressed: () => _toggleFavorite(context),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        CatalogSourceNote(catalog: catalog),
      ],
    );
  }
}

/// Aba Linhas com o catálogo oficial: busca, lista e detalhe da linha. As
/// linhas favoritas (par ponto + linha) continuam no topo.
class CatalogLinesPanel extends StatefulWidget {
  const CatalogLinesPanel({
    required this.catalog,
    required this.query,
    required this.openLineId,
    required this.onOpenLine,
    required this.onOpenStop,
    super.key,
  });

  final TransitCatalog catalog;

  /// Texto da busca; fica com a página para sobreviver à troca de aba.
  final TextEditingController query;

  /// Linha aberta (detalhe), ou `null` para a lista.
  final String? openLineId;
  final ValueChanged<String?> onOpenLine;

  /// Abre os detalhes de um ponto (aba Pontos).
  final ValueChanged<String> onOpenStop;

  @override
  State<CatalogLinesPanel> createState() => _CatalogLinesPanelState();
}

class _CatalogLinesPanelState extends State<CatalogLinesPanel> {
  int _shown = catalogLinesPage;

  TextEditingController get _query => widget.query;

  void _openLine(String? id) => widget.onOpenLine(id);

  @override
  Widget build(BuildContext context) {
    final open = widget.openLineId;
    if (open != null) {
      return _LineDetail(
        catalog: widget.catalog,
        lineId: open,
        onBack: () => _openLine(null),
        onOpenStop: widget.onOpenStop,
      );
    }
    final tokens = context.tokens;
    final results = widget.catalog.searchLines(_query.text);
    final shown = results.take(_shown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('catalog-lines-search'),
          controller: _query,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() => _shown = catalogLinesPage),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: l10n.catalogLinesSearchHint,
            filled: true,
            fillColor: tokens.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.field),
              borderSide: BorderSide(color: tokens.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.field),
              borderSide: BorderSide(color: tokens.hairline),
            ),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.clearCode,
                    onPressed: () => setState(_query.clear),
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: Space.sm),
        if (_query.text.isEmpty) _FavoriteLines(onOpenStop: widget.onOpenStop),
        SectionLabel(
          icon: Icons.format_list_bulleted_rounded,
          label: l10n.catalogLinesAllTitle,
          trailing: Text(
            '${results.length}',
            style: monoStyle(TextStyle(fontSize: 12, color: tokens.mutedText)),
          ),
        ),
        const SizedBox(height: Space.xs),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Text(
              l10n.catalogLinesNoResults,
              style: TextStyle(color: tokens.mutedText),
            ),
          ),
        for (final line in shown) ...[
          _LineTile(
            key: ValueKey('catalog-line-${line.id}'),
            line: line,
            variants: widget.catalog.variantsOf(line.id).length,
            onTap: () => _openLine(line.id),
          ),
          const SizedBox(height: Space.xs),
        ],
        if (results.length > shown.length)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _shown += catalogLinesPage),
              child: Text(l10n.catalogShowMore),
            ),
          ),
        const SizedBox(height: Space.xs),
        CatalogSourceNote(catalog: widget.catalog),
      ],
    );
  }
}

/// Linhas favoritas (par ponto + linha) já guardadas: atalho para o ponto.
class _FavoriteLines extends StatelessWidget {
  const _FavoriteLines({required this.onOpenStop});

  final ValueChanged<String> onOpenStop;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SavedStopsCubit, SavedStopsState, List<SavedLine>>(
      selector: (state) => state.lines,
      builder: (context, lines) {
        if (lines.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(
              icon: Icons.star_rounded,
              label: l10n.favoriteLinesSection,
            ),
            const SizedBox(height: Space.xs),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final line in lines)
                  ActionChip(
                    avatar: const Icon(Icons.star_rounded, size: 16),
                    label: Text('${line.routeId} · ${line.stopCode}'),
                    tooltip: l10n.lineOpenArrivals(line.routeId, line.stopCode),
                    onPressed: () => onOpenStop(line.stopCode),
                  ),
              ],
            ),
            const SizedBox(height: Space.md),
          ],
        );
      },
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.variants,
    required this.onTap,
    super.key,
  });

  final CatalogLine line;
  final int variants;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final name = line.name ?? '';
    return Semantics(
      button: true,
      label: l10n.catalogOpenLine(line.id, name),
      excludeSemantics: true,
      child: Material(
        color: tokens.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: tokens.hairline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Row(
                children: [
                  RoutePlate(line.id),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: tokens.strongText,
                          ),
                        ),
                        Text(
                          [
                            l10n.catalogVariantCount(variants),
                            ?line.type,
                            if (line.cities.isNotEmpty) line.cities.join(', '),
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: tokens.mutedText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Detalhe da linha: dados do cadastro, variantes e pontos associados
/// (sem ordem nem sentido, que ainda não foram validados).
class _LineDetail extends StatelessWidget {
  const _LineDetail({
    required this.catalog,
    required this.lineId,
    required this.onBack,
    required this.onOpenStop,
  });

  final TransitCatalog catalog;
  final String lineId;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final line = catalog.line(lineId);
    final back = Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const ValueKey('catalog-line-back'),
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
        label: Text(l10n.catalogBackToLines),
      ),
    );
    if (line == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [back, Text(l10n.catalogLineNotFound)],
      );
    }
    final variants = catalog.variantsOf(line.id);
    final stops = catalog.stopsOf(line.id);
    final statuses = {
      for (final v in variants)
        if (v.status != null) displayCase(v.status),
    };
    final cities = {...line.cities, ...catalog.stopCitiesOf(line.id)}.toList()
      ..sort();

    Widget fact(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: Space.xxs),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: tokens.mutedText),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: tokens.strongText),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 14, height: 1.3),
      ),
    );

    return Column(
      key: ValueKey('catalog-line-detail-${line.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        back,
        Row(
          children: [
            RoutePlate(line.id, filled: true),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                line.name ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: tokens.strongText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        if (statuses.isNotEmpty)
          fact(l10n.catalogLineStatus, statuses.join(', ')),
        if (line.type != null || line.form != null)
          fact(l10n.catalogLineType, [?line.type, ?line.form].join(' · ')),
        if (cities.isNotEmpty) fact(l10n.catalogLineCities, cities.join(', ')),
        const SizedBox(height: Space.sm),
        SectionLabel(
          icon: Icons.call_split_rounded,
          label: l10n.catalogLineVariants,
          trailing: Text(
            '${variants.length}',
            style: monoStyle(TextStyle(fontSize: 12, color: tokens.mutedText)),
          ),
        ),
        const SizedBox(height: Space.xs),
        for (final v in variants) ...[
          Container(
            key: ValueKey('catalog-variant-${v.id}'),
            padding: const EdgeInsets.all(Space.sm),
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: tokens.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: v.code,
                        style: monoStyle(
                          TextStyle(
                            fontWeight: FontWeight.w700,
                            color: tokens.accentText,
                          ),
                        ),
                      ),
                      TextSpan(text: '  ${v.name ?? ''}'),
                    ],
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tokens.strongText,
                  ),
                ),
                const SizedBox(height: Space.xxs),
                Text(
                  [
                    ?v.characteristic,
                    if (v.status != null) displayCase(v.status),
                    if (v.validFrom != null)
                      l10n.catalogValidFrom(v.validFrom!),
                  ].join(' · '),
                  style: TextStyle(fontSize: 12.5, color: tokens.mutedText),
                ),
                if (v.origin != null)
                  Text(
                    '${l10n.catalogLineOrigin}: ${v.origin}',
                    style: TextStyle(fontSize: 13, color: tokens.softText),
                  ),
                if (v.destination != null)
                  Text(
                    '${l10n.catalogLineDestination}: ${v.destination}',
                    style: TextStyle(fontSize: 13, color: tokens.softText),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.xs),
        ],
        const SizedBox(height: Space.xs),
        SectionLabel(
          icon: Icons.location_on_outlined,
          label: l10n.catalogLineStops(stops.length),
        ),
        const SizedBox(height: Space.xxs),
        FootNote(child: Text(l10n.catalogLineStopsNote)),
        const SizedBox(height: Space.xs),
        for (final stop in stops.take(80)) ...[
          CatalogStopTile(
            key: ValueKey('catalog-stop-${stop.id}'),
            stop: stop,
            onTap: () => onOpenStop(stop.id),
          ),
          const SizedBox(height: Space.xs),
        ],
        if (stops.length > 80)
          FootNote(child: Text(l10n.catalogResultsMore(80, stops.length))),
        const SizedBox(height: Space.xs),
        CatalogSourceNote(catalog: catalog),
      ],
    );
  }
}

/// Atalho para widgets que só querem o catálogo se ele estiver ligado.
extension CatalogStopLabel on BuildContext {
  /// Endereço do ponto no catálogo (para favoritos e recentes), ou `null`.
  CatalogStop? catalogStop(String code) => catalog?.stop(code);
}
