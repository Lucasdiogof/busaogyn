import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/busao_tokens.dart';
import '../../../core/ui/busao_components.dart';
import '../domain/stop_sequence.dart';
import '../domain/timetable.dart';
import '../domain/transit_catalog.dart';
import 'catalog_widgets.dart';

/// Quantas paradas a sequência mostra antes de "Mostrar todas".
const sequencePreview = 12;

String _date(BuildContext context, String? iso) {
  final date = DateTime.tryParse(iso ?? '');
  if (date == null) return iso ?? '?';
  return MaterialLocalizations.of(context).formatCompactDate(date);
}

/// Faixa colorida com ícone e texto (validade, avisos).
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.background,
    required this.text,
    this.action,
    super.key,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.plate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    color: tokens.strongText,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (action != null)
            Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}

/// Horários programados da linha (planilhas OSO), por tipo de dia. Só
/// partidas: nada de horário de passagem nos pontos, sentido ou local de
/// partida (a planilha não informa). Validade sempre explícita.
class LineTimetableSection extends StatefulWidget {
  const LineTimetableSection({
    required this.catalog,
    required this.lineId,
    this.now,
    super.key,
  });

  final TransitCatalog catalog;
  final String lineId;

  /// Relógio (testes); escolhe o tipo de dia inicial.
  final DateTime Function()? now;

  @override
  State<LineTimetableSection> createState() => _LineTimetableSectionState();
}

class _LineTimetableSectionState extends State<LineTimetableSection> {
  late ServiceDay _day = serviceDayOf((widget.now ?? DateTime.now)());
  String? _code;
  final _revealed = <String>{};

  @override
  void didUpdateWidget(LineTimetableSection old) {
    super.didUpdateWidget(old);
    if (old.lineId != widget.lineId) {
      _code = null;
      _revealed.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final timetables = widget.catalog.timetablesOf(widget.lineId);
    return Column(
      key: ValueKey('timetable-${widget.lineId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(icon: Icons.schedule_rounded, label: l10n.scheduleTitle),
        const SizedBox(height: Space.xs),
        if (timetables.isEmpty)
          FootNote(
            key: const ValueKey('timetable-none'),
            child: Text(l10n.scheduleNone),
          ),
        for (final t in timetables) ...[
          _timetable(context, tokens, t),
          const SizedBox(height: Space.sm),
        ],
      ],
    );
  }

  Widget _timetable(
    BuildContext context,
    BusaoTokens tokens,
    CatalogTimetable t,
  ) {
    final date = _date(context, t.sheetDate);
    switch (t.validity) {
      case TimetableValidity.insufficient:
        return _Notice(
          key: const ValueKey('timetable-insufficient'),
          icon: Icons.block_rounded,
          color: tokens.mutedText,
          background: tokens.scheduledContainer,
          text: l10n.scheduleInsufficient,
        );
      case TimetableValidity.old when !_revealed.contains(t.id):
        return _Notice(
          key: const ValueKey('timetable-old'),
          icon: Icons.history_rounded,
          color: tokens.unconfirmed,
          background: tokens.unconfirmedContainer,
          text: l10n.scheduleOld(date),
          action: TextButton(
            key: const ValueKey('timetable-show-old'),
            onPressed: () => setState(() => _revealed.add(t.id)),
            child: Text(l10n.scheduleShowOld),
          ),
        );
      case _:
    }
    final trips = widget.catalog.tripsOf(t.id);
    final codes = <String?, String?>{
      for (final g in trips) g.code: g.variantId,
    };
    final sortedCodes = codes.keys.whereType<String>().toList()..sort();
    final code = codes.containsKey(_code) ? _code : null;
    final departures = departuresOf(
      trips,
      _day,
      codes: code == null ? null : {code},
    );
    final showCode = code == null && sortedCodes.length > 1;
    final hasHalf = departures.any(
      (d) => d.kind != null && d.kind != TripKind.full,
    );
    final hasNextDay = departures.any((d) => d.nextDay);
    final hasRepeated = departures.any((d) => d.repeated > 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (t.validity) {
          TimetableValidity.confirmed => _Notice(
            key: const ValueKey('timetable-confirmed'),
            icon: Icons.verified_outlined,
            color: tokens.realtime,
            background: tokens.realtimeContainer,
            text: l10n.scheduleConfirmed(date),
          ),
          TimetableValidity.recent => _Notice(
            key: const ValueKey('timetable-recent'),
            icon: Icons.info_outline_rounded,
            color: tokens.unconfirmed,
            background: tokens.unconfirmedContainer,
            text: l10n.scheduleRecent(date),
          ),
          _ => _Notice(
            key: const ValueKey('timetable-old-shown'),
            icon: Icons.history_rounded,
            color: tokens.unconfirmed,
            background: tokens.unconfirmedContainer,
            text: l10n.scheduleOld(date),
          ),
        },
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final (day, label) in [
              (ServiceDay.weekday, l10n.scheduleDayWeekday),
              (ServiceDay.saturday, l10n.scheduleDaySaturday),
              (ServiceDay.sundayHoliday, l10n.scheduleDaySunday),
            ])
              ChoiceChip(
                key: ValueKey('timetable-day-${day.name}'),
                label: Text(label),
                selected: _day == day,
                onSelected: (_) => setState(() => _day = day),
              ),
          ],
        ),
        if (sortedCodes.length > 1) ...[
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              ChoiceChip(
                key: const ValueKey('timetable-code-all'),
                label: Text(l10n.scheduleAllCodes),
                selected: code == null,
                onSelected: (_) => setState(() => _code = null),
              ),
              for (final c in sortedCodes)
                ChoiceChip(
                  key: ValueKey('timetable-code-$c'),
                  label: Text(
                    codes[c] == null ? l10n.scheduleCodeUnregistered(c) : c,
                    style: monoStyle(null),
                  ),
                  selected: code == c,
                  onSelected: (_) => setState(() => _code = c),
                ),
            ],
          ),
        ],
        const SizedBox(height: Space.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.scheduleCount(departures.length),
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
        if (departures.isEmpty)
          Text(
            l10n.scheduleEmptyDay,
            key: const ValueKey('timetable-empty-day'),
            style: TextStyle(fontSize: 13, color: tokens.mutedText),
          )
        else
          Wrap(
            key: ValueKey('timetable-times-${_day.name}'),
            spacing: Space.xxs,
            runSpacing: Space.xxs,
            children: [
              for (final d in departures)
                _DepartureCell(departure: d, showCode: showCode),
            ],
          ),
        const SizedBox(height: Space.xs),
        if (hasNextDay || hasHalf || hasRepeated)
          FootNote(
            child: Text(
              [
                if (hasNextDay) l10n.scheduleLegendNextDay,
                if (hasHalf) l10n.scheduleLegendHalf,
                if (hasRepeated) l10n.scheduleLegendRepeated,
              ].join(' · '),
            ),
          ),
        FootNote(child: Text(l10n.scheduleDepartureNote)),
        if (t.source != null)
          FootNote(child: Text(l10n.scheduleSource(t.oso ?? '—', t.source!))),
      ],
    );
  }
}

class _DepartureCell extends StatelessWidget {
  const _DepartureCell({required this.departure, required this.showCode});

  final Departure departure;
  final bool showCode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final d = departure;
    final marks = [
      if (d.nextDay) '+1',
      switch (d.kind) {
        TripKind.halfStartsAtTurn => 'MI',
        TripKind.halfEndsAtTurn => 'MF',
        _ => null,
      },
      if (d.repeated > 1) '×${d.repeated}',
      if (showCode && d.code != null) d.code!,
    ].whereType<String>();
    return Container(
      constraints: const BoxConstraints(minWidth: 60),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            d.clock,
            style: monoStyle(
              TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: d.nextDay ? tokens.softText : tokens.strongText,
              ),
            ),
          ),
          if (marks.isNotEmpty)
            Text(
              marks.join(' '),
              style: monoStyle(
                TextStyle(fontSize: 10.5, color: tokens.mutedText),
              ),
            ),
        ],
      ),
    );
  }
}

/// Uma parada numa lista: número (se ordenada), endereço, código e marcas.
class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.catalog,
    required this.stopId,
    required this.onTap,
    this.index,
    this.tags = const [],
    this.highlight = false,
    super.key,
  });

  final TransitCatalog catalog;
  final String stopId;
  final int? index;
  final List<String> tags;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final stop = catalog.stop(stopId);
    final title = stop?.address ?? l10n.catalogStation;
    return Material(
      color: highlight ? tokens.accentSoft : tokens.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.plate),
        side: BorderSide(color: highlight ? tokens.accent : tokens.hairline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.plate),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.sm,
              vertical: Space.xs,
            ),
            child: Row(
              children: [
                if (index != null) ...[
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$index',
                      style: monoStyle(
                        TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tokens.accentText,
                        ),
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tokens.strongText,
                        ),
                      ),
                      Text(
                        [stopId, ?stop?.place, ...tags].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: tokens.mutedText),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded, color: tokens.mutedText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paradas do trajeto selecionado. Ordem só com status `estimated` e sempre
/// rotulada como estimativa; `partial` lista os pontos sem ordem; ambíguos
/// ficam de fora e são contados.
class ShapeStopsSection extends StatefulWidget {
  const ShapeStopsSection({
    required this.catalog,
    required this.shape,
    required this.onOpenStop,
    super.key,
  });

  final TransitCatalog catalog;
  final CatalogShape shape;
  final ValueChanged<String> onOpenStop;

  @override
  State<ShapeStopsSection> createState() => _ShapeStopsSectionState();
}

class _ShapeStopsSectionState extends State<ShapeStopsSection> {
  bool _all = false;

  @override
  void didUpdateWidget(ShapeStopsSection old) {
    super.didUpdateWidget(old);
    if (old.shape.id != widget.shape.id) _all = false;
  }

  @override
  Widget build(BuildContext context) {
    final seq = widget.catalog.sequenceOf(widget.shape.id);
    final direction = directionLabel(widget.shape.direction);
    if (seq == null || seq.status == SequenceStatus.none) {
      return FootNote(
        key: const ValueKey('sequence-none'),
        child: Text(l10n.sequenceNone),
      );
    }
    final estimated = seq.status == SequenceStatus.estimated;
    final count = estimated ? seq.entries.length : seq.stopIds.length;
    final shown = _all ? count : count.clamp(0, sequencePreview);
    final repeated = <String>{};
    final seen = <String>{};
    for (final e in seq.entries) {
      if (!seen.add(e.stopId)) repeated.add(e.stopId);
    }
    return Column(
      key: ValueKey('sequence-${seq.status.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          icon: estimated
              ? Icons.format_list_numbered_rounded
              : Icons.scatter_plot_outlined,
          label: estimated
              ? l10n.sequenceTitle(count, direction)
              : l10n.sequencePartialTitle(count),
        ),
        const SizedBox(height: Space.xxs),
        FootNote(
          child: Text(
            estimated ? l10n.sequenceEstimatedNote : l10n.sequencePartialNote,
          ),
        ),
        const SizedBox(height: Space.xs),
        for (var i = 0; i < shown; i++) ...[
          if (estimated)
            _StopRow(
              key: ValueKey('sequence-stop-$i'),
              catalog: widget.catalog,
              stopId: seq.entries[i].stopId,
              index: i + 1,
              tags: [
                if (seq.entries[i].level == StopLevel.medium)
                  l10n.sequenceUncertain,
                if (repeated.contains(seq.entries[i].stopId))
                  l10n.sequenceRepeated,
              ],
              onTap: () => widget.onOpenStop(seq.entries[i].stopId),
            )
          else
            _StopRow(
              key: ValueKey('sequence-stop-$i'),
              catalog: widget.catalog,
              stopId: seq.stopIds[i],
              onTap: () => widget.onOpenStop(seq.stopIds[i]),
            ),
          const SizedBox(height: Space.xxs),
        ],
        if (shown < count)
          Center(
            child: TextButton(
              key: const ValueKey('sequence-show-all'),
              onPressed: () => setState(() => _all = true),
              child: Text(l10n.sequenceShowAll(count)),
            ),
          ),
        if (seq.ambiguous.isNotEmpty)
          FootNote(child: Text(l10n.sequenceAmbiguous(seq.ambiguous.length))),
      ],
    );
  }
}

/// Onde o ponto aparece nas sequências estimadas confiáveis. Nada aparece
/// quando não há (sem ruído).
class StopItinerary extends StatelessWidget {
  const StopItinerary({
    required this.catalog,
    required this.stopId,
    required this.onOpenRoute,
    super.key,
  });

  final TransitCatalog catalog;
  final String stopId;
  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final places = catalog.itineraryOf(stopId);
    if (places.isEmpty) return const SizedBox.shrink();
    return Column(
      key: ValueKey('itinerary-$stopId'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          icon: Icons.format_list_numbered_rounded,
          label: l10n.itineraryTitle,
        ),
        const SizedBox(height: Space.xs),
        for (final (shape, position) in places.take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xxs),
            child: Material(
              color: tokens.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.plate),
                side: BorderSide(color: tokens.hairline),
              ),
              child: InkWell(
                key: ValueKey('itinerary-${shape.id}'),
                borderRadius: BorderRadius.circular(Radii.plate),
                onTap: () => onOpenRoute(shape.id),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.sm,
                      vertical: Space.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.itineraryRow(
                              directionLabel(shape.direction),
                              position,
                              catalog.sequenceOf(shape.id)!.entries.length,
                              shape.variantId,
                            ),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: tokens.strongText,
                            ),
                          ),
                        ),
                        Icon(Icons.map_outlined, color: tokens.accentText),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        FootNote(child: Text(l10n.itineraryNote)),
      ],
    );
  }
}

/// Próximos pontos do ônibus acompanhado, só quando [NextStops.available].
/// Sem sequência confiável, uma linha explica; sem associação confirmada,
/// nada (a nota da associação já explica).
class NextStopsCard extends StatelessWidget {
  const NextStopsCard({
    required this.catalog,
    required this.next,
    required this.onOpenStop,
    super.key,
  });

  final TransitCatalog catalog;
  final NextStops next;
  final ValueChanged<String> onOpenStop;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    switch (next.reason) {
      case NextStopsReason.notConfirmed:
        return const SizedBox.shrink();
      case NextStopsReason.sequenceUnreliable:
        return FootNote(
          key: const ValueKey('next-stops-unreliable'),
          child: Text(l10n.nextStopsUnreliable),
        );
      case NextStopsReason.endOfRoute:
        return FootNote(
          key: const ValueKey('next-stops-end'),
          child: Text(l10n.nextStopsEnd),
        );
      case NextStopsReason.ok:
    }
    final shown = next.remaining.take(5).toList();
    return Container(
      key: const ValueKey('next-stops'),
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.nextStopsTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.strongText,
            ),
          ),
          const SizedBox(height: Space.xxs),
          Text(
            next.nextConfident
                ? l10n.nextStopsRemaining(next.remaining.length)
                : '${l10n.nextStopsUncertain} '
                      '${l10n.nextStopsRemaining(next.remaining.length)}',
            key: ValueKey('next-stops-confident-${next.nextConfident}'),
            style: TextStyle(fontSize: 12.5, color: tokens.softText),
          ),
          const SizedBox(height: Space.xs),
          for (var i = 0; i < shown.length; i++) ...[
            _StopRow(
              key: ValueKey('next-stop-$i'),
              catalog: catalog,
              stopId: shown[i].stopId,
              highlight: i == 0 && next.nextConfident,
              tags: [
                if (i == 0 && next.nextConfident) l10n.nextStopLabel,
                if (shown[i].level == StopLevel.medium) l10n.sequenceUncertain,
              ],
              onTap: () => onOpenStop(shown[i].stopId),
            ),
            const SizedBox(height: Space.xxs),
          ],
          FootNote(child: Text(l10n.nextStopsNote)),
        ],
      ),
    );
  }
}
