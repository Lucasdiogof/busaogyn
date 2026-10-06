enum ArrivalQuality {
  realtime,
  scheduled,
  unknown,
}

final class Arrival {
  const Arrival({
    required this.vehicleId,
    required this.vehicleNumber,
    required this.minutes,
    required this.plannedArrival,
    required this.predictedArrival,
    required this.realtime,
    required this.quality,
  });

  final String? vehicleId;
  final String? vehicleNumber;
  final int? minutes;
  final String? plannedArrival;
  final String? predictedArrival;
  final bool realtime;
  final ArrivalQuality quality;
}

final class ArrivalGroup {
  const ArrivalGroup({
    required this.routeId,
    required this.destination,
    required this.next,
    required this.following,
  });

  final String routeId;
  final String? destination;
  final Arrival next;
  final Arrival? following;
}

final class ArrivalSnapshot {
  const ArrivalSnapshot({
    required this.groups,
    required this.stopId,
    required this.fetchedAt,
    required this.stale,
    required this.ageSeconds,
  });

  final List<ArrivalGroup> groups;
  final String stopId;
  final DateTime fetchedAt;
  final bool stale;
  final int ageSeconds;
}
