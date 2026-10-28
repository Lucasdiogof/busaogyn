import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/busao_tokens.dart';
import '../../../core/ui/busao_components.dart';
import '../domain/nearby.dart';
import '../domain/transit_catalog.dart';
import 'catalog_widgets.dart';

enum NearbyStatus { idle, locating, located, failed }

/// Acima disto a posição é "aproximada" e a tela avisa (raio, em metros).
const nearbyImpreciseM = 150.0;

/// "Perto de mim": uma leitura da posição só quando o passageiro toca. O
/// resultado fica aqui (sobrevive à troca de aba) e nunca é gravado.
class NearbyController extends ChangeNotifier {
  NearbyController(this.catalog, this.location);

  final TransitCatalog catalog;
  final LocationService location;

  NearbyStatus status = NearbyStatus.idle;
  LocationFix? fix;
  List<NearbyStop> stops = const [];
  LocationProblem? problem;

  Future<void> locate() async {
    if (status == NearbyStatus.locating) return;
    status = NearbyStatus.locating;
    problem = null;
    notifyListeners();
    try {
      final found = await location.current();
      fix = found;
      stops = nearbyStops(catalog, found.position);
      status = NearbyStatus.located;
    } on LocationFailure catch (e) {
      fix = null;
      stops = const [];
      problem = e.problem;
      status = NearbyStatus.failed;
    }
    notifyListeners();
  }

  /// Esquece a posição (o ponto "você" sai do mapa).
  void clear() {
    status = NearbyStatus.idle;
    fix = null;
    stops = const [];
    problem = null;
    notifyListeners();
  }
}

class NearbyStopsSection extends StatelessWidget {
  const NearbyStopsSection({
    required this.controller,
    required this.onOpenStop,
    super.key,
  });

  final NearbyController controller;
  final ValueChanged<String> onOpenStop;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final locating = c.status == NearbyStatus.locating;
        final located = c.status == NearbyStatus.located;
        return Column(
          key: const ValueKey('nearby'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!located) ...[
              FilledButton.tonalIcon(
                key: const ValueKey('nearby-locate'),
                onPressed: locating ? null : c.locate,
                icon: locating
                    ? const BusaoLoader(size: 18)
                    : const Icon(Icons.near_me_rounded),
                label: Text(locating ? l10n.nearbyLocating : l10n.nearbyButton),
              ),
              const SizedBox(height: Space.xs),
              if (c.problem case final problem?)
                _Problem(controller: c, problem: problem)
              else
                FootNote(child: Text(l10n.nearbyHint)),
            ] else
              ..._results(context, c),
          ],
        );
      },
    );
  }

  List<Widget> _results(BuildContext context, NearbyController c) {
    final tokens = context.tokens;
    final accuracy = c.fix!.accuracyM;
    return [
      SectionLabel(
        icon: Icons.near_me_rounded,
        label: l10n.nearbyTitle,
        trailing: TextButton(
          key: const ValueKey('nearby-refresh'),
          onPressed: c.locate,
          child: Text(l10n.nearbyRefresh),
        ),
      ),
      if (accuracy > nearbyImpreciseM) ...[
        FootNote(
          child: Text(
            l10n.nearbyImprecise(accuracy.round()),
            style: TextStyle(color: tokens.unconfirmed),
          ),
        ),
        const SizedBox(height: Space.xs),
      ],
      if (c.stops.isEmpty)
        MessageView(
          icon: Icons.location_searching_rounded,
          title: l10n.nearbyEmpty,
        )
      else ...[
        for (final near in c.stops) ...[
          CatalogStopTile(
            key: ValueKey('nearby-${near.stop.id}'),
            stop: near.stop,
            detail: l10n.nearbyDistance(near.meters),
            onTap: () => onOpenStop(near.stop.id),
          ),
          const SizedBox(height: Space.xs),
        ],
        FootNote(child: Text(l10n.nearbyStraightLine)),
      ],
    ];
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.controller, required this.problem});

  final NearbyController controller;
  final LocationProblem problem;

  @override
  Widget build(BuildContext context) {
    // No navegador não há como abrir os ajustes: a mensagem diz onde liberar.
    final settings =
        !kIsWeb &&
        (problem == LocationProblem.deniedForever ||
            problem == LocationProblem.serviceOff);
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FootNote(
            child: Text(switch (problem) {
              LocationProblem.denied => l10n.nearbyDenied,
              LocationProblem.deniedForever when kIsWeb =>
                l10n.nearbyDeniedBrowser,
              LocationProblem.deniedForever => l10n.nearbyDeniedForever,
              LocationProblem.serviceOff => l10n.nearbyServiceOff,
              LocationProblem.timeout => l10n.nearbyTimeout,
              LocationProblem.unavailable => l10n.nearbyUnavailable,
            }),
          ),
          if (settings)
            TextButton(
              key: const ValueKey('nearby-settings'),
              onPressed: () => controller.location.openSettings(problem),
              child: Text(l10n.nearbyOpenSettings),
            ),
        ],
      ),
    );
  }
}
