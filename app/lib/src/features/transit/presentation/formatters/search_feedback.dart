import '../../../../core/l10n/l10n.dart';
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

  /// A falha é de conexão ou da fonte, não do código digitado: o campo não
  /// ganha borda de erro e vale tentar de novo.
  bool get isConnectivity =>
      kind == SearchFeedbackKind.offline ||
      kind == SearchFeedbackKind.timeout ||
      kind == SearchFeedbackKind.unavailable;

  /// Código buscado, quando era um número válido.
  final String? stopId;

  static SearchFeedback get invalidCode => SearchFeedback(
    SearchFeedbackKind.invalidCode,
    l10n.searchInvalidTitle,
    l10n.searchInvalidBody,
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
        l10n.searchNotFoundTitle,
        l10n.searchNotFoundBody,
        stopId: stopId,
      ),
      SearchFeedbackKind.timeout => SearchFeedback(
        kind,
        l10n.searchTimeoutTitle,
        l10n.searchTimeoutBody,
        stopId: stopId,
      ),
      SearchFeedbackKind.offline => SearchFeedback(
        kind,
        l10n.searchOfflineTitle,
        l10n.searchOfflineBody,
        stopId: stopId,
      ),
      _ => SearchFeedback(
        SearchFeedbackKind.unavailable,
        l10n.searchUnavailableTitle,
        l10n.searchUnavailableBody,
        stopId: stopId,
      ),
    };
  }
}
