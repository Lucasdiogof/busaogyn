import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';

enum SearchFeedbackKind { invalidCode, notFound, timeout, offline, unavailable }

/// Retorno curto de uma busca de ponto que falhou, mostrado junto do campo.
/// Nunca carrega a mensagem técnica do Worker.
class SearchFeedback {
  const SearchFeedback(this.kind, this.title, this.message, {this.stopId});

  final SearchFeedbackKind kind;
  final String title;
  final String message;

  /// Código buscado, quando era um número válido.
  final String? stopId;

  static const invalidCode = SearchFeedback(
    SearchFeedbackKind.invalidCode,
    'Digite o código do ponto',
    'Use só os números da placa do ponto.',
  );

  /// Classifica o erro da consulta de chegadas de [stopId].
  factory SearchFeedback.fromError(Object error, String stopId) {
    final kind = switch (error) {
      ApiException(code: ApiClient.timeoutCode || 'SOURCE_TIMEOUT') =>
        SearchFeedbackKind.timeout,
      ApiException(code: ApiClient.networkErrorCode) =>
        SearchFeedbackKind.offline,
      // A RMTC responde com payload inválido para código inexistente; não há
      // como distinguir de um ponto real com defeito, então o texto convida
      // a conferir o código.
      ApiException(code: 'SOURCE_INVALID_RESPONSE' || 'INVALID_STOP') =>
        SearchFeedbackKind.notFound,
      ApiException(statusCode: 404) => SearchFeedbackKind.notFound,
      _ => SearchFeedbackKind.unavailable,
    };
    return switch (kind) {
      SearchFeedbackKind.notFound => SearchFeedback(
        kind,
        'Ponto não encontrado',
        'Confira o código e tente novamente.',
        stopId: stopId,
      ),
      SearchFeedbackKind.timeout => SearchFeedback(
        kind,
        'A consulta demorou demais',
        'Tente novamente em instantes.',
        stopId: stopId,
      ),
      SearchFeedbackKind.offline => SearchFeedback(
        kind,
        'Sem conexão',
        'Verifique sua internet e tente de novo.',
        stopId: stopId,
      ),
      _ => SearchFeedback(
        SearchFeedbackKind.unavailable,
        'Serviço temporariamente indisponível',
        'Tente novamente em alguns minutos.',
        stopId: stopId,
      ),
    };
  }
}
