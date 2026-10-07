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
