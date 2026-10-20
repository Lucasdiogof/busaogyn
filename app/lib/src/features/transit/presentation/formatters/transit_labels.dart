import '../../../../core/l10n/l10n.dart';
import '../../domain/entities/arrival.dart';
import '../../domain/entities/tracked_vehicle.dart';
import '../cubit/stop_arrivals_cubit.dart';

/// Qualidade efetivamente exibida. Só é "tempo real" quando a API marca a
/// chegada como realtime E a qualidade como realtime; qualquer dúvida vira
/// [ArrivalQuality.unknown], nunca realtime.
ArrivalQuality displayQuality(Arrival arrival) {
  return switch (arrival.quality) {
    ArrivalQuality.realtime when arrival.isConfirmedRealtime =>
      ArrivalQuality.realtime,
    ArrivalQuality.scheduled when !arrival.realtime => ArrivalQuality.scheduled,
    _ => ArrivalQuality.unknown,
  };
}

String qualityLabel(ArrivalQuality quality) {
  return switch (quality) {
    ArrivalQuality.realtime => l10n.qualityRealtime,
    ArrivalQuality.scheduled => l10n.qualityScheduled,
    ArrivalQuality.unknown => l10n.qualityUnknownLong,
  };
}

/// Rótulo curto para os selos compactos das chegadas.
String qualityShortLabel(ArrivalQuality quality) {
  return switch (quality) {
    ArrivalQuality.realtime => l10n.qualityRealtime,
    ArrivalQuality.scheduled => l10n.qualityScheduled,
    ArrivalQuality.unknown => l10n.qualityUnknownShort,
  };
}

/// Acompanhar só faz sentido com GPS e identidade de veículo da fonte.
bool canTrack(Arrival arrival) {
  return arrival.isConfirmedRealtime && arrival.vehicleNumber != null;
}

String minutesSemantics(int? minutes) {
  if (minutes == null) return l10n.minutesUnknown;
  if (minutes <= 0) return l10n.minutesLessThanOneLong;
  return l10n.minutesLong(minutes);
}

String punctualityLabel(VehiclePunctuality punctuality) {
  return switch (punctuality) {
    VehiclePunctuality.onTime => l10n.punctualityOnTime,
    VehiclePunctuality.delayed => l10n.punctualityDelayed,
    VehiclePunctuality.early => l10n.punctualityEarly,
    VehiclePunctuality.unknown => l10n.punctualityUnknown,
  };
}

String accessibilityLabel(bool? accessible) {
  return switch (accessible) {
    true => l10n.accessible,
    false => l10n.accessibilityNotIndicated,
    null => l10n.accessibilityUnknown,
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

/// Estado da posição do ônibus acompanhado. Separa o que a fonte não
/// informou ([unavailable]) de falha de conexão ([connection]) e de posição
/// antiga ([stale]): nenhum deles é apresentado como "ao vivo".
enum PositionState { searching, live, aging, stale, unavailable, connection }

class PositionStatus {
  const PositionStatus(this.state, this.text);

  final PositionState state;
  final String text;

  FreshnessTone get tone => switch (state) {
    PositionState.live => FreshnessTone.fresh,
    PositionState.searching || PositionState.aging => FreshnessTone.aging,
    PositionState.stale => FreshnessTone.stale,
    PositionState.unavailable ||
    PositionState.connection => FreshnessTone.unavailable,
  };
}

PositionStatus positionStatus(TrackingInfo tracking, DateTime now) {
  final vehicle = tracking.vehicle;
  if (vehicle?.data?.position == null) {
    return switch (tracking.phase) {
      TrackingPhase.searching => PositionStatus(
        PositionState.searching,
        l10n.positionSearching,
      ),
      TrackingPhase.failing => PositionStatus(
        PositionState.connection,
        l10n.positionConnection,
      ),
      _ => PositionStatus(PositionState.unavailable, l10n.positionUnavailable),
    };
  }

  final age = snapshotAgeSeconds(
    apiAgeSeconds: vehicle!.ageSeconds,
    receivedAt: tracking.receivedAt,
    now: now,
  );
  if (vehicle.stale || tracking.phase != TrackingPhase.active) {
    return PositionStatus(
      PositionState.stale,
      l10n.positionOutdated(ageLabel(age)),
    );
  }
  if (age <= recentThresholdSeconds) {
    return PositionStatus(PositionState.live, l10n.positionLive(ageLabel(age)));
  }
  return PositionStatus(PositionState.aging, l10n.positionLast(ageLabel(age)));
}

Freshness arrivalsFreshness(StopArrivalsLoaded state, DateTime now) {
  final age = snapshotAgeSeconds(
    apiAgeSeconds: state.arrivals.ageSeconds,
    receivedAt: state.arrivalsReceivedAt,
    now: now,
  );
  if (state.arrivals.stale) {
    return Freshness(l10n.freshnessStale(ageLabel(age)), FreshnessTone.stale);
  }
  if (age <= recentThresholdSeconds) {
    return Freshness(l10n.freshnessNow, FreshnessTone.fresh);
  }
  return Freshness(l10n.freshnessAge(ageLabel(age)), FreshnessTone.aging);
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
      return switch (tracking.phase) {
        TrackingPhase.searching => LiveStatus(
          l10n.liveSearchingLabel,
          l10n.liveSearchingDetail,
          LiveTone.scheduled,
        ),
        TrackingPhase.failing => LiveStatus(
          l10n.liveConnectionLabel,
          l10n.liveConnectionDetail,
          LiveTone.stale,
        ),
        // A fonte não informou a posição agora; o app segue tentando.
        _ => LiveStatus(
          l10n.liveLocatingLabel,
          l10n.liveLocatingDetail,
          LiveTone.stale,
        ),
      };
    }
    final age = snapshotAgeSeconds(
      apiAgeSeconds: snapshot!.ageSeconds,
      receivedAt: tracking.receivedAt,
      now: now,
    );
    if (snapshot.stale || tracking.phase != TrackingPhase.active) {
      return LiveStatus(
        l10n.liveOutdated,
        l10n.ago(ageLabel(age)),
        LiveTone.stale,
      );
    }
    if (age <= recentThresholdSeconds) {
      return LiveStatus(
        l10n.liveLabel,
        l10n.ago(ageLabel(age)),
        LiveTone.live,
        receivedAt: tracking.receivedAt,
      );
    }
    return LiveStatus(
      l10n.livePosition,
      l10n.ago(ageLabel(age)),
      LiveTone.aging,
    );
  }

  final age = snapshotAgeSeconds(
    apiAgeSeconds: state.arrivals.ageSeconds,
    receivedAt: state.arrivalsReceivedAt,
    now: now,
  );
  if (state.arrivals.stale || state.refreshError != null) {
    return LiveStatus(
      l10n.liveOutdated,
      l10n.ago(ageLabel(age)),
      LiveTone.stale,
    );
  }
  final groups = state.arrivals.data;
  if (groups.isEmpty) {
    return LiveStatus(l10n.liveNoEstimate, l10n.now, LiveTone.scheduled);
  }
  if (!hasRealtimeArrival(groups)) {
    return LiveStatus(
      l10n.qualityScheduled,
      l10n.liveNoGps,
      LiveTone.scheduled,
    );
  }
  if (age <= recentThresholdSeconds) {
    return LiveStatus(
      l10n.liveLabel,
      age <= 5 ? l10n.now : l10n.ago(ageLabel(age)),
      LiveTone.live,
      receivedAt: state.arrivalsReceivedAt,
    );
  }
  return LiveStatus(l10n.liveEstimate, l10n.ago(ageLabel(age)), LiveTone.aging);
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
  return l10n.positionAgeShort(ageLabel(age));
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
  if (value == null || value.isEmpty) return l10n.destinationUnknown;
  return l10n.headingTo(destinationLabel(value));
}
