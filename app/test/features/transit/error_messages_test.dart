import 'package:busaogyn/src/core/network/api_client.dart';
import 'package:busaogyn/src/core/network/api_exception.dart';
import 'package:busaogyn/src/features/transit/presentation/formatters/error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

ApiException _api(String code, {bool retryable = true}) => ApiException(
  code: code,
  message: 'RMTC arrivals payload has an unexpected shape.',
  retryable: retryable,
);

void main() {
  test('mensagem técnica do Worker não vai para a tela', () {
    final message = friendlyErrorMessage(
      _api('SOURCE_INVALID_RESPONSE'),
      ErrorSubject.arrivals,
    );
    expect(message, isNot(contains('RMTC arrivals payload')));
    expect(message, contains('Confira o código'));
  });

  test('timeout do app tem mensagem própria', () {
    expect(
      friendlyErrorMessage(_api(ApiClient.timeoutCode), ErrorSubject.arrivals),
      'A consulta demorou mais que o esperado. Tente novamente.',
    );
  });

  test('códigos conhecidos do Worker', () {
    expect(
      friendlyErrorMessage(_api('SOURCE_TIMEOUT'), ErrorSubject.position),
      contains('RMTC demorou'),
    );
    expect(
      friendlyErrorMessage(
        _api('INVALID_STOP', retryable: false),
        ErrorSubject.arrivals,
      ),
      contains('Código de ponto inválido'),
    );
  });

  test('código desconhecido cai no texto genérico', () {
    expect(
      friendlyErrorMessage(_api('X', retryable: false), ErrorSubject.arrivals),
      'Não foi possível concluir a consulta.',
    );
  });
}
