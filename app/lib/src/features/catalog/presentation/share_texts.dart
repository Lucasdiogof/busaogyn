import '../../../core/l10n/l10n.dart';
import '../domain/transit_catalog.dart';
import '../domain/trip_planner.dart';
import 'catalog_widgets.dart';

/// Textos compartilháveis: só o que a tela mostra, com o aviso de que
/// cadastro e estimativas não são informação oficial. Sem links: o app ainda
/// não tem endereço público com abertura direta (ver doc da Etapa C).

String stopShareText(String code, {CatalogStop? stop}) => [
  l10n.shareStop(code),
  if (stop != null) ...[?stop.address, ?stop.place],
  l10n.shareFooter,
].join('\n');

String lineShareText(TransitCatalog catalog, CatalogLine line) => [
  l10n.shareLine(line.id, line.name ?? ''),
  for (final v in catalog.variantsOf(line.id).take(4))
    if (v.origin != null && v.destination != null)
      '• ${v.origin} → ${v.destination}',
  l10n.shareCatalogNote,
  l10n.shareFooter,
].join('\n');

String tripShareText(TransitCatalog catalog, TripOption option) {
  String where(String id) {
    final stop = catalog.stop(id);
    final address = stop?.address;
    return address == null
        ? stopCode(stop, id)
        : '$address (${stopCode(stop, id)})';
  }

  final legs = option.legs;
  return [
    l10n.shareTripTitle(
      where(legs.first.board.stopId),
      where(legs.last.alight.stopId),
    ),
    for (var i = 0; i < legs.length; i++)
      l10n.shareTripLeg(
        i + 1,
        legs[i].shape.lineId,
        where(legs[i].board.stopId),
        where(legs[i].alight.stopId),
      ),
    l10n.shareTripNote,
    l10n.shareFooter,
  ].join('\n');
}
