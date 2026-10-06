enum ArrivalQuality {
  realtime,
  scheduled,
  unknown;

  static ArrivalQuality fromJson(Object? value) {
    return switch (value) {
      'realtime' => ArrivalQuality.realtime,
      'scheduled' => ArrivalQuality.scheduled,
      _ => ArrivalQuality.unknown,
    };
  }
}

class Arrival {
  const Arrival({
    required this.vehicleId,
    required this.vehicleNumber,
    required this.minutes,
    required this.plannedArrival,
    required this.predictedArrival,
    required this.realtime,
    required this.quality,
  });

  factory Arrival.fromJson(Map<String, dynamic> json) {
    return Arrival(
      vehicleId: json['vehicleId'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      minutes: (json['minutes'] as num?)?.toInt(),
      plannedArrival: json['plannedArrival'] as String?,
      predictedArrival: json['predictedArrival'] as String?,
      realtime: json['realtime'] == true,
      quality: ArrivalQuality.fromJson(json['quality']),
    );
  }

  final String? vehicleId;
  final String? vehicleNumber;
  final int? minutes;
  final String? plannedArrival;
  final String? predictedArrival;
  final bool realtime;
  final ArrivalQuality quality;
}

class ArrivalGroup {
  const ArrivalGroup({
    required this.routeId,
    required this.destination,
    required this.next,
    required this.following,
  });

  factory ArrivalGroup.fromJson(Map<String, dynamic> json) {
    return ArrivalGroup(
      routeId: json['routeId'] as String,
      destination: json['destination'] as String?,
      next: Arrival.fromJson(json['next'] as Map<String, dynamic>),
      following: json['following'] is Map<String, dynamic>
          ? Arrival.fromJson(json['following'] as Map<String, dynamic>)
          : null,
    );
  }

  final String routeId;
  final String? destination;
  final Arrival next;
  final Arrival? following;
}
