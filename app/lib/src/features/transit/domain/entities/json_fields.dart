/// Leitura tolerante dos campos da API BusãoGyn. Um tipo inesperado vira
/// `null` (dado ausente), nunca um valor inventado nem um `TypeError`.
library;

String? jsonString(Object? value) => value is String ? value : null;

int? jsonInt(Object? value) =>
    value is num && value.isFinite ? value.toInt() : null;

/// Número de veículo exibível e consultável: vazio ou só zeros ("0",
/// "0000") é ausência de veículo, não o "ônibus 0".
String? jsonVehicleNumber(Object? value) {
  final number = jsonString(value)?.trim();
  if (number == null || number.isEmpty || RegExp(r'^0+$').hasMatch(number)) {
    return null;
  }
  return number;
}
