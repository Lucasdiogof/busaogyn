import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';

enum ErrorSubject { arrivals, position }

/// Mensagem amigável, no idioma do app, para um erro. As mensagens do Worker são
/// técnicas (em inglês) e nunca vão direto para a tela.
String friendlyErrorMessage(Object error, ErrorSubject subject) {
  if (error is FormatException) {
    return l10n.errFormat;
  }
  if (error is! ApiException) {
    return subject == ErrorSubject.arrivals
        ? l10n.errArrivalsGeneric
        : l10n.errPositionGeneric;
  }

  return switch (error.code) {
    ApiClient.timeoutCode => l10n.errTimeout,
    ApiClient.networkErrorCode => l10n.errNetwork,
    'SOURCE_TIMEOUT' => l10n.errSourceTimeout,
    'SOURCE_UNAVAILABLE' ||
    'SOURCE_ACCESS_RESTRICTED' => l10n.errSourceUnavailable,
    'SOURCE_INVALID_RESPONSE' when subject == ErrorSubject.arrivals =>
      l10n.errSourceInvalidArrivals,
    'SOURCE_INVALID_RESPONSE' => l10n.errSourceInvalidPosition,
    'INVALID_STOP' => l10n.errInvalidStop,
    'INVALID_VEHICLE' => l10n.errInvalidVehicle,
    'INVALID_RESPONSE' => l10n.errInvalidResponse,
    _ when error.retryable => l10n.errRetryable,
    _ => l10n.errGeneric,
  };
}

/// Falha de conexão ou serviço fora do ar (vale tentar de novo), em oposição
/// a uma resposta que chegou sem dado utilizável para o ônibus. Só o
/// primeiro caso é "conexão instável"; o segundo é posição indisponível.
bool isConnectivityError(Object error) {
  if (error is FormatException) return false;
  if (error is! ApiException) return true;
  return switch (error.code) {
    ApiClient.timeoutCode ||
    ApiClient.networkErrorCode ||
    'SOURCE_TIMEOUT' ||
    'SOURCE_UNAVAILABLE' ||
    'SOURCE_ACCESS_RESTRICTED' => true,
    'SOURCE_INVALID_RESPONSE' ||
    'INVALID_RESPONSE' ||
    'INVALID_VEHICLE' => false,
    _ => error.retryable && error.statusCode != 404,
  };
}
