import 'json_fields.dart';

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
      vehicleId: jsonString(json['vehicleId']),
      vehicleNumber: jsonVehicleNumber(json['vehicleNumber']),
      minutes: jsonInt(json['minutes']),
      plannedArrival: jsonString(json['plannedArrival']),
      predictedArrival: jsonString(json['predictedArrival']),
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

  /// Tempo real confirmado: a API marca a chegada como realtime E a
  /// qualidade como realtime. É a única regra para exibir "Tempo real",
  /// permitir acompanhar e mostrar o ônibus no mapa.
  bool get isConfirmedRealtime =>
      realtime && quality == ArrivalQuality.realtime;
}

class ArrivalGroup {
  const ArrivalGroup({
    required this.routeId,
    required this.destination,
    required this.next,
    required this.following,
  });

  /// Sem `routeId` ou sem `next` o grupo não é exibível: [FormatException].
  factory ArrivalGroup.fromJson(Map<String, dynamic> json) {
    final routeId = jsonString(json['routeId'])?.trim();
    final next = json['next'];
    if (routeId == null || routeId.isEmpty || next is! Map<String, dynamic>) {
      throw const FormatException('Arrival group without routeId or next.');
    }
    final following = json['following'];
    return ArrivalGroup(
      routeId: routeId,
      destination: jsonString(json['destination']),
      next: Arrival.fromJson(next),
      following: following is Map<String, dynamic>
          ? Arrival.fromJson(following)
          : null,
    );
  }

  final String routeId;
  final String? destination;
  final Arrival next;
  final Arrival? following;
}
