import '../../domain/entities/arrival.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../cubit/stop_arrivals_cubit.dart';

/// Qualidade efetivamente exibida. Só é "tempo real" quando a API marca a
/// chegada como realtime E a qualidade como realtime; qualquer dúvida vira
/// [ArrivalQuality.unknown], nunca realtime.
ArrivalQuality displayQuality(Arrival arrival) {
  return switch (arrival.quality) {
    ArrivalQuality.realtime when arrival.realtime => ArrivalQuality.realtime,
    ArrivalQuality.scheduled when !arrival.realtime => ArrivalQuality.scheduled,
    _ => ArrivalQuality.unknown,
  };
}

String qualityLabel(ArrivalQuality quality) {
  return switch (quality) {
    ArrivalQuality.realtime => 'Tempo real',
    ArrivalQuality.scheduled => 'Programado',
    ArrivalQuality.unknown => 'Informação não confirmada',
  };
}

/// Rótulo curto para os selos compactos das chegadas.
String qualityShortLabel(ArrivalQuality quality) {
  return switch (quality) {
    ArrivalQuality.realtime => 'Tempo real',
    ArrivalQuality.scheduled => 'Programado',
    ArrivalQuality.unknown => 'Não confirmado',
  };
}

/// Acompanhar só faz sentido com GPS e identidade de veículo da fonte.
bool canTrack(Arrival arrival) {
  return displayQuality(arrival) == ArrivalQuality.realtime &&
      arrival.vehicleNumber != null;
}

String minutesLabel(int? minutes) {
  if (minutes == null) return '—';
  if (minutes <= 0) return '< 1 min';
  return '$minutes min';
}

String minutesSemantics(int? minutes) {
  if (minutes == null) return 'tempo não informado';
  if (minutes <= 0) return 'menos de 1 minuto';
  if (minutes == 1) return '1 minuto';
  return '$minutes minutos';
}

String punctualityLabel(VehiclePunctuality punctuality) {
  return switch (punctuality) {
    VehiclePunctuality.onTime => 'No horário',
    VehiclePunctuality.delayed => 'Atrasado',
    VehiclePunctuality.early => 'Adiantado',
    VehiclePunctuality.unknown => 'Pontualidade não informada',
  };
}

String accessibilityLabel(bool? accessible) {
  return switch (accessible) {
    true => 'Acessível',
    false => 'Acessibilidade não indicada',
    null => 'Acessibilidade não informada',
  };
}

/// "25 s", "3 min", "1 h".
String ageLabel(int seconds) {
  if (seconds < 60) return '$seconds s';
  if (seconds < 3600) return '${seconds ~/ 60} min';
  return '${seconds ~/ 3600} h';
}

/// Idade de um snapshot: o `ageSeconds` da API (idade no cache do Worker)
/// mais o tempo local desde que a resposta chegou. `fetchedAt` é o instante
/// da coleta pelo BusãoGyn, não o GPS — por isso só falamos em "consultada".
int snapshotAgeSeconds({
  required int apiAgeSeconds,
  required DateTime? receivedAt,
  required DateTime now,
}) {
  final local = receivedAt == null ? 0 : now.difference(receivedAt).inSeconds;
  return apiAgeSeconds + (local < 0 ? 0 : local);
}

/// Até aqui consideramos "recente" (o tracking atualiza a cada ~15 s).
const recentThresholdSeconds = 30;

enum FreshnessTone { fresh, aging, stale, unavailable }

class Freshness {
  const Freshness(this.text, this.tone);

  final String text;
  final FreshnessTone tone;
}

Freshness positionFreshness(TrackingInfo tracking, DateTime now) {
  final vehicle = tracking.vehicle;
  if (vehicle?.data?.position == null) {
    return switch (tracking.phase) {
      TrackingPhase.searching => const Freshness(
        'Buscando posição',
        FreshnessTone.aging,
      ),
      _ => const Freshness('Posição indisponível', FreshnessTone.unavailable),
    };
  }

  final age = snapshotAgeSeconds(
    apiAgeSeconds: vehicle!.ageSeconds,
    receivedAt: tracking.receivedAt,
    now: now,
  );
  if (vehicle.stale || tracking.phase != TrackingPhase.active) {
    return Freshness(
      'Posição temporariamente desatualizada · consultada há ${ageLabel(age)}',
      FreshnessTone.stale,
    );
  }
  if (age <= recentThresholdSeconds) {
    return const Freshness(
      'Dados atualizados recentemente',
      FreshnessTone.fresh,
    );
  }
  return Freshness(
    'Última posição consultada há ${ageLabel(age)}',
    FreshnessTone.aging,
  );
}

Freshness arrivalsFreshness(StopArrivalsLoaded state, DateTime now) {
  final age = snapshotAgeSeconds(
    apiAgeSeconds: state.arrivals.ageSeconds,
    receivedAt: state.arrivalsReceivedAt,
    now: now,
  );
  if (state.arrivals.stale) {
    return Freshness(
      'Dados temporariamente desatualizados · há ${ageLabel(age)}',
      FreshnessTone.stale,
    );
  }
  if (age <= recentThresholdSeconds) {
    return const Freshness('Atualizado agora', FreshnessTone.fresh);
  }
  return Freshness('Atualizado há ${ageLabel(age)}', FreshnessTone.aging);
}

/// Tom do indicador de status no topo do mapa.
enum LiveTone {
  /// Dado com GPS da fonte, consultado há pouco: único caso "Ao vivo".
  live,

  /// Só horário de tabela (ou nenhuma previsão): nada é "ao vivo".
  scheduled,

  /// Havia tempo real, mas a última consulta já envelheceu.
  aging,

  /// Fonte instável, dado desatualizado ou posição indisponível.
  stale,
}

class LiveStatus {
  const LiveStatus(this.label, this.detail, this.tone, {this.receivedAt});

  final String label;
  final String detail;
  final LiveTone tone;

  /// Quando o dado exibido chegou; muda a cada resposta nova.
  final DateTime? receivedAt;

  String get semantics => '$label, $detail';
}

bool hasRealtimeArrival(List<ArrivalGroup> groups) {
  for (final group in groups) {
    if (displayQuality(group.next) == ArrivalQuality.realtime) return true;
    final following = group.following;
    if (following != null &&
        displayQuality(following) == ArrivalQuality.realtime) {
      return true;
    }
  }
  return false;
}

/// Status resumido do que está na tela. Responder não basta para ser "Ao
/// vivo": é preciso dado em tempo real (GPS da fonte), não marcado como stale
/// e consultado dentro de [recentThresholdSeconds]. `null` quando não há o
/// que qualificar (antes da primeira consulta, carregando ou com erro).
LiveStatus? liveStatus(StopArrivalsState state, DateTime now) {
  if (state is! StopArrivalsLoaded) return null;

  final tracking = state.tracking;
  if (tracking != null) {
    final snapshot = tracking.vehicle;
    if (snapshot?.data?.position == null) {
      return tracking.phase == TrackingPhase.searching
          ? const LiveStatus('Buscando', 'posição', LiveTone.scheduled)
          : const LiveStatus('Sem posição', 'do ônibus', LiveTone.stale);
    }
    final age = snapshotAgeSeconds(
      apiAgeSeconds: snapshot!.ageSeconds,
      receivedAt: tracking.receivedAt,
      now: now,
    );
    if (snapshot.stale || tracking.phase != TrackingPhase.active) {
      return LiveStatus('Desatualizado', 'há ${ageLabel(age)}', LiveTone.stale);
    }
    if (age <= recentThresholdSeconds) {
      return LiveStatus(
        'Ao vivo',
        'há ${ageLabel(age)}',
        LiveTone.live,
        receivedAt: tracking.receivedAt,
      );
    }
    return LiveStatus('Posição', 'há ${ageLabel(age)}', LiveTone.aging);
  }

  final age = snapshotAgeSeconds(
    apiAgeSeconds: state.arrivals.ageSeconds,
    receivedAt: state.arrivalsReceivedAt,
    now: now,
  );
  if (state.arrivals.stale || state.refreshError != null) {
    return LiveStatus('Desatualizado', 'há ${ageLabel(age)}', LiveTone.stale);
  }
  final groups = state.arrivals.data;
  if (groups.isEmpty) {
    return const LiveStatus('Sem previsão', 'agora', LiveTone.scheduled);
  }
  if (!hasRealtimeArrival(groups)) {
    return const LiveStatus('Programado', 'sem GPS', LiveTone.scheduled);
  }
  if (age <= recentThresholdSeconds) {
    return LiveStatus(
      'Ao vivo',
      age <= 5 ? 'agora' : 'há ${ageLabel(age)}',
      LiveTone.live,
      receivedAt: state.arrivalsReceivedAt,
    );
  }
  return LiveStatus('Previsão', 'há ${ageLabel(age)}', LiveTone.aging);
}

/// "posição há 8 s" para o cabeçalho do acompanhamento.
String? positionAgeLabel(TrackingInfo tracking, DateTime now) {
  final snapshot = tracking.vehicle;
  if (snapshot?.data?.position == null) return null;
  final age = snapshotAgeSeconds(
    apiAgeSeconds: snapshot!.ageSeconds,
    receivedAt: tracking.receivedAt,
    now: now,
  );
  return 'posição há ${ageLabel(age)}';
}

/// Chegada do ônibus acompanhado entre as chegadas do ponto consultado.
({ArrivalGroup group, Arrival arrival})? trackedArrival(
  List<ArrivalGroup> groups,
  String vehicleNumber,
) {
  for (final group in groups) {
    if (group.next.vehicleNumber == vehicleNumber) {
      return (group: group, arrival: group.next);
    }
    final following = group.following;
    if (following?.vehicleNumber == vehicleNumber) {
      return (group: group, arrival: following!);
    }
  }
  return null;
}

/// Mantém o prefixo curto do destino ("T", "PQ") colado à palavra seguinte,
/// para "T MARANATA" não quebrar como "T" / "MARANATA".
String destinationLabel(String destination) {
  return destination.trim().replaceFirstMapped(
    RegExp(r'^([A-Za-zÀ-ÿ]{1,2}\.?)\s+(?=\S)'),
    (match) => '${match[1]} ',
  );
}

/// "Indo para T MARANATA"; sem destino informado, não inventa um.
String headingToLabel(String? destination) {
  final value = destination?.trim();
  if (value == null || value.isEmpty) return 'Destino não informado';
  return 'Indo para ${destinationLabel(value)}';
}
