import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/busao_tokens.dart';
import '../../../core/ui/busao_components.dart';
import '../domain/route_geometry.dart';
import '../domain/transit_catalog.dart';
import '../domain/trip_planner.dart';
import 'catalog_widgets.dart';

enum PlannerField { origin, destination }

/// Estado do planejador (fica com a página para sobreviver à troca de aba).
/// Tudo local: os textos digitados não saem do aparelho.
class TripPlannerController extends ChangeNotifier {
  TripPlannerController(this.catalog);

  final TransitCatalog catalog;

  /// Grafo montado no primeiro uso (~2 ms com a base real).
  late final TripPlanner planner = TripPlanner(catalog);

  bool active = false;
  String? origin;
  String? destination;

  /// Campo que o próximo toque num ponto do mapa vai preencher.
  PlannerField? picking;
  TripPlan? plan;
  int? selected;

  TripOption? get selectedOption {
    final i = selected;
    final options = plan?.options;
    return i == null || options == null || i >= options.length
        ? null
        : options[i];
  }

  bool get canSearch => origin != null && destination != null;

  void open() {
    active = true;
    notifyListeners();
  }

  void close() {
    active = false;
    picking = null;
    plan = null;
    selected = null;
    notifyListeners();
  }

  void _invalidate() {
    plan = null;
    selected = null;
  }

  void set(PlannerField field, String? stopId) {
    if (field == PlannerField.origin) {
      origin = stopId;
    } else {
      destination = stopId;
    }
    picking = null;
    _invalidate();
    notifyListeners();
  }

  void swap() {
    final previous = origin;
    origin = destination;
    destination = previous;
    _invalidate();
    notifyListeners();
  }

  void startPicking(PlannerField? field) {
    picking = field;
    notifyListeners();
  }

  /// Toque num ponto do mapa: preenche o campo pendente. `false` quando não
  /// há campo esperando (o toque segue o fluxo normal do mapa).
  bool pickFromMap(String stopId) {
    final field = picking;
    if (!active || field == null) return false;
    set(field, stopId);
    return true;
  }

  void search() {
    if (!canSearch) return;
    plan = planner.plan(origin!, destination!);
    selected = plan!.options.isEmpty ? null : 0;
    notifyListeners();
  }

  void select(int index) {
    selected = index;
    notifyListeners();
  }
}

/// Enquadramento de uma alternativa (todos os trechos desenhados).
GeoBounds tripBounds(TripOption option) =>
    GeoBounds.of([for (final leg in option.legs) ...leg.path]);

String _km(BuildContext context, int meters) => NumberFormat(
  '0.0',
  Localizations.localeOf(context).toString(),
).format(meters / 1000);

/// Planejador: origem, destino, inverter, buscar, alternativas.
class TripPlannerPanel extends StatefulWidget {
  const TripPlannerPanel({
    required this.controller,
    required this.onOpenStop,
    super.key,
  });

  final TripPlannerController controller;
  final ValueChanged<String> onOpenStop;

  @override
  State<TripPlannerPanel> createState() => _TripPlannerPanelState();
}

class _TripPlannerPanelState extends State<TripPlannerPanel> {
  final _queries = {
    PlannerField.origin: TextEditingController(),
    PlannerField.destination: TextEditingController(),
  };

  TripPlannerController get _c => widget.controller;

  @override
  void dispose() {
    for (final q in _queries.values) {
      q.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final tokens = context.tokens;
        final plan = _c.plan;
        return Column(
          key: const ValueKey('trip-planner'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.alt_route_rounded, color: tokens.accentText),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    l10n.plannerTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: tokens.strongText,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('planner-close'),
                  tooltip: l10n.plannerClose,
                  onPressed: _c.close,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            FootNote(child: Text(l10n.plannerIntro)),
            const SizedBox(height: Space.sm),
            _field(context, PlannerField.origin),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const ValueKey('planner-swap'),
                tooltip: l10n.plannerSwap,
                onPressed: _c.origin == null && _c.destination == null
                    ? null
                    : _c.swap,
                icon: const Icon(Icons.swap_vert_rounded),
              ),
            ),
            _field(context, PlannerField.destination),
            const SizedBox(height: Space.sm),
            FilledButton.icon(
              key: const ValueKey('planner-search'),
              onPressed: _c.canSearch ? _c.search : null,
              icon: const Icon(Icons.search_rounded),
              label: Text(l10n.plannerSearch),
            ),
            const SizedBox(height: Space.sm),
            if (plan != null) ..._results(context, plan),
          ],
        );
      },
    );
  }

  Widget _field(BuildContext context, PlannerField field) {
    final tokens = context.tokens;
    final id = field == PlannerField.origin ? _c.origin : _c.destination;
    final label = field == PlannerField.origin
        ? l10n.plannerOrigin
        : l10n.plannerDestination;
    final picking = _c.picking == field;
    if (id != null) {
      final stop = _c.catalog.stop(id);
      final covered = _c.planner.covers(id);
      return Container(
        key: ValueKey('planner-${field.name}-$id'),
        padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, 0, Space.xs),
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(Radii.field),
          border: Border.all(color: tokens.hairline),
        ),
        child: Row(
          children: [
            Icon(
              field == PlannerField.origin
                  ? Icons.trip_origin_rounded
                  : Icons.place_rounded,
              color: tokens.accentText,
            ),
            const SizedBox(width: Space.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: tokens.mutedText),
                  ),
                  Text(
                    stop?.address ?? l10n.catalogStation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tokens.strongText,
                    ),
                  ),
                  Text(
                    [
                      id,
                      ?stop?.place,
                      if (!covered) l10n.plannerNotCovered,
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: tokens.mutedText),
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('planner-clear-${field.name}'),
              tooltip: l10n.clearCode,
              onPressed: () => _c.set(field, null),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
    }
    final query = _queries[field]!;
    final results = query.text.trim().isEmpty
        ? const <CatalogStop>[]
        : _c.catalog.searchStops(query.text, limit: 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: ValueKey('planner-input-${field.name}'),
          controller: query,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            hintText: l10n.plannerSearchHint,
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
            suffixIcon: IconButton(
              key: ValueKey('planner-pick-${field.name}'),
              tooltip: l10n.plannerPickOnMap,
              isSelected: picking,
              onPressed: () => _c.startPicking(picking ? null : field),
              icon: const Icon(Icons.ads_click_rounded),
            ),
          ),
        ),
        if (picking)
          Padding(
            padding: const EdgeInsets.only(top: Space.xxs),
            child: FootNote(
              key: ValueKey('planner-picking-${field.name}'),
              child: Text(l10n.plannerPicking(label)),
            ),
          ),
        for (final stop in results)
          InkWell(
            key: ValueKey('planner-result-${field.name}-${stop.id}'),
            onTap: () {
              query.clear();
              FocusScope.of(context).unfocus();
              _c.set(field, stop.id);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.xs,
                vertical: Space.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: tokens.mutedText,
                  ),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      [
                        stop.address ?? l10n.catalogStation,
                        stop.id,
                        if (!_c.planner.covers(stop.id)) l10n.plannerNotCovered,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: tokens.softText),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _results(BuildContext context, TripPlan plan) {
    final message = switch (plan.status) {
      TripPlanStatus.ok => null,
      TripPlanStatus.sameStop => l10n.plannerSameStop,
      TripPlanStatus.unknownStop => l10n.plannerUnknownStop,
      TripPlanStatus.noCoverageOrigin => l10n.plannerNoCoverageOrigin,
      TripPlanStatus.noCoverageDestination => l10n.plannerNoCoverageDestination,
      TripPlanStatus.noRoute => l10n.plannerNoRoute,
    };
    if (message != null) {
      return [
        MessageView(
          key: ValueKey('planner-status-${plan.status.name}'),
          icon: Icons.wrong_location_outlined,
          title: l10n.plannerNoResultTitle,
          body: message,
        ),
      ];
    }
    return [
      SectionLabel(
        icon: Icons.format_list_bulleted_rounded,
        label: l10n.plannerResultsTitle(plan.options.length),
      ),
      const SizedBox(height: Space.xs),
      for (var i = 0; i < plan.options.length; i++) ...[
        _OptionCard(
          key: ValueKey('planner-option-$i'),
          catalog: _c.catalog,
          option: plan.options[i],
          selected: _c.selected == i,
          onSelect: () => _c.select(i),
          onOpenStop: widget.onOpenStop,
        ),
        const SizedBox(height: Space.xs),
      ],
      if (plan.truncated) FootNote(child: Text(l10n.plannerTruncated)),
      FootNote(child: Text(l10n.plannerNoTimes)),
    ];
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.catalog,
    required this.option,
    required this.selected,
    required this.onSelect,
    required this.onOpenStop,
    super.key,
  });

  final TransitCatalog catalog;
  final TripOption option;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<String> onOpenStop;

  String _caution(TripCaution c) => switch (c) {
    TripCaution.orderNotCrossChecked => l10n.plannerCautionOrder,
    TripCaution.uncertainStop => l10n.plannerCautionUncertain,
    TripCaution.repeatedPass => l10n.plannerCautionRepeated,
    TripCaution.walkUnverified => l10n.plannerCautionWalk,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final reliable = option.reliability == TripReliability.reliable;
    Widget stopLine(
      IconData icon,
      String label,
      String stopId, {
      String? extra,
    }) {
      final stop = catalog.stop(stopId);
      return InkWell(
        onTap: () => onOpenStop(stopId),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: tokens.accentText),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$label: ',
                        style: TextStyle(color: tokens.mutedText),
                      ),
                      TextSpan(
                        text: stop?.address ?? l10n.catalogStation,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: tokens.strongText,
                        ),
                      ),
                      TextSpan(text: ' · $stopId'),
                      if (extra != null) TextSpan(text: ' · $extra'),
                    ],
                  ),
                  style: TextStyle(fontSize: 13, color: tokens.softText),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget legLine(TripLeg leg) => Padding(
      padding: const EdgeInsets.only(left: 26, top: 2, bottom: 2),
      child: Row(
        children: [
          IntrinsicWidth(child: RoutePlate(leg.shape.lineId, dense: true)),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text(
              l10n.plannerLeg(
                directionLabel(leg.shape.direction),
                _km(context, leg.distanceM),
                leg.stops,
                leg.shape.variantId,
              ),
              style: TextStyle(fontSize: 12.5, color: tokens.softText),
            ),
          ),
        ],
      ),
    );

    final legs = option.legs;
    return Material(
      color: selected ? tokens.accentSoft : tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(
          color: selected ? tokens.accent : tokens.hairline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: Space.xs,
                runSpacing: Space.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    key: ValueKey(
                      'planner-reliability-${option.reliability.name}',
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: reliable
                          ? tokens.accent
                          : tokens.unconfirmedContainer,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          reliable
                              ? Icons.verified_rounded
                              : Icons.info_outline_rounded,
                          size: 14,
                          color: reliable
                              ? tokens.onAccent
                              : tokens.unconfirmed,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          reliable
                              ? l10n.plannerReliable
                              : l10n.plannerEstimated,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: reliable
                                ? tokens.onAccent
                                : tokens.unconfirmed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    [
                      l10n.plannerBuses(legs.length),
                      if (option.transfers == 0)
                        l10n.plannerDirect
                      else
                        l10n.plannerTransfers(option.transfers),
                    ].join(' · '),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tokens.strongText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xs),
              stopLine(
                Icons.trip_origin_rounded,
                l10n.plannerBoard,
                legs.first.board.stopId,
              ),
              legLine(legs.first),
              if (legs.length == 2) ...[
                stopLine(
                  Icons.transfer_within_a_station_rounded,
                  l10n.plannerTransfer,
                  legs.first.alight.stopId,
                  extra: option.walkM > 0
                      ? l10n.plannerWalk(option.walkM)
                      : null,
                ),
                if (option.walkM > 0)
                  stopLine(
                    Icons.directions_bus_outlined,
                    l10n.plannerBoard,
                    legs.last.board.stopId,
                  ),
                legLine(legs.last),
              ],
              stopLine(
                Icons.place_rounded,
                l10n.plannerAlight,
                legs.last.alight.stopId,
              ),
              if (option.cautions.isNotEmpty) ...[
                const SizedBox(height: Space.xxs),
                for (final c in option.cautions)
                  Text(
                    '• ${_caution(c)}',
                    style: TextStyle(fontSize: 12, color: tokens.mutedText),
                  ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: ValueKey('planner-show-${option.key}'),
                  onPressed: onSelect,
                  icon: Icon(
                    selected ? Icons.map_rounded : Icons.map_outlined,
                    size: 18,
                  ),
                  label: Text(
                    selected ? l10n.plannerOnMap : l10n.plannerShowOnMap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Atalho da aba Pontos para abrir o planejador.
class PlanTripButton extends StatelessWidget {
  const PlanTripButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: OutlinedButton.icon(
      key: const ValueKey('planner-open'),
      onPressed: onPressed,
      icon: const Icon(Icons.alt_route_rounded, size: 18),
      label: Text(l10n.plannerOpen),
    ),
  );
}
