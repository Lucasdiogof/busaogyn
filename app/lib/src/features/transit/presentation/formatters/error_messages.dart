import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';

enum ErrorSubject { arrivals, position }

/// Mensagem amigável em português para um erro. As mensagens do Worker são
/// técnicas (em inglês) e nunca vão direto para a tela.
String friendlyErrorMessage(Object error, ErrorSubject subject) {
  if (error is FormatException) {
    return 'O BusãoGyn recebeu dados em formato inesperado. Tente novamente.';
  }
  if (error is! ApiException) {
    return subject == ErrorSubject.arrivals
        ? 'Não foi possível consultar este ponto agora.'
        : 'Não foi possível localizar este ônibus agora.';
  }

  return switch (error.code) {
    ApiClient.timeoutCode =>
      'A consulta demorou mais que o esperado. Tente novamente.',
    ApiClient.networkErrorCode =>
      'Sem conexão com o BusãoGyn. Verifique sua internet.',
    'SOURCE_TIMEOUT' =>
      'A RMTC demorou para responder. Tente novamente em instantes.',
    'SOURCE_UNAVAILABLE' || 'SOURCE_ACCESS_RESTRICTED' =>
      'A fonte de dados da RMTC está indisponível agora. '
          'Tente novamente em instantes.',
    'SOURCE_INVALID_RESPONSE' when subject == ErrorSubject.arrivals =>
      'A RMTC não retornou dados válidos para este ponto. '
          'Confira o código ou tente novamente.',
    'SOURCE_INVALID_RESPONSE' =>
      'A RMTC não retornou dados válidos para este ônibus agora.',
    'INVALID_STOP' => 'Código de ponto inválido. Use apenas números.',
    'INVALID_VEHICLE' =>
      'Este ônibus não tem um número válido para acompanhamento.',
    'INVALID_RESPONSE' =>
      'O BusãoGyn recebeu uma resposta inesperada. Tente novamente.',
    _ when error.retryable =>
      'O serviço está instável agora. Tente novamente em instantes.',
    _ => 'Não foi possível concluir a consulta.',
  };
}
