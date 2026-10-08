import '../../domain/entities/arrival.dart';

/// Quantos ônibus secundários o mapa mostra por padrão.
const defaultSecondaryVehicleLimit = 6;

/// Ônibus em tempo real conhecido pelas chegadas do ponto consultado.
class SecondaryCandidate {
  const SecondaryCandidate({
    required this.vehicleNumber,
    required this.routeId,
    required this.destination,
    required this.minutes,
  });

  final String vehicleNumber;
  final String routeId;
  final String? destination;
  final int? minutes;
}

/// Monta o conjunto deduplicado de ônibus secundários a partir das chegadas.
///
/// Só entram `next` e `following` com tempo real confirmado
/// ([Arrival.isConfirmedRealtime], a mesma regra do selo "Tempo real" e do
/// botão de acompanhar) e `vehicleNumber` válido. O ônibus acompanhado é
/// excluído (ele tem o próprio marcador). Acima de [limit], vence o menor ETA
/// (sem ETA por último); o desempate é o número do veículo, para a escolha
/// ser estável entre atualizações.
List<SecondaryCandidate> selectSecondaryCandidates(
  List<ArrivalGroup> groups, {
  String? trackedVehicleNumber,
  int limit = defaultSecondaryVehicleLimit,
}) {
  final byNumber = <String, SecondaryCandidate>{};

  void consider(ArrivalGroup group, Arrival? arrival) {
    if (arrival == null || !arrival.isConfirmedRealtime) return;
    final number = arrival.vehicleNumber?.trim();
    if (number == null || number.isEmpty || number == trackedVehicleNumber) {
      return;
    }
    final candidate = SecondaryCandidate(
      vehicleNumber: number,
      routeId: group.routeId,
      destination: group.destination,
      minutes: arrival.minutes,
    );
    final existing = byNumber[number];
    if (existing == null || _etaOrder(candidate, existing) < 0) {
      byNumber[number] = candidate;
    }
  }

  for (final group in groups) {
    consider(group, group.next);
    consider(group, group.following);
  }

  final sorted = byNumber.values.toList()..sort(_etaOrder);
  return limit >= sorted.length ? sorted : sorted.sublist(0, limit);
}

int _etaOrder(SecondaryCandidate a, SecondaryCandidate b) {
  final am = a.minutes;
  final bm = b.minutes;
  if (am != bm) {
    if (am == null) return 1;
    if (bm == null) return -1;
    return am.compareTo(bm);
  }
  return a.vehicleNumber.compareTo(b.vehicleNumber);
}
