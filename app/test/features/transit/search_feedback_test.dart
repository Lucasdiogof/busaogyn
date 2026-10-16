import 'package:busaogyn/src/core/network/api_exception.dart';
import 'package:busaogyn/src/features/transit/presentation/formatters/search_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

SearchFeedback _from(String code, {int? status}) => SearchFeedback.fromError(
  ApiException(code: code, message: 'x', retryable: true, statusCode: status),
  '30402',
);

void main() {
  group('SearchFeedback.isConnectivity', () {
    test('conexão, tempo esgotado e fonte indisponível valem retry', () {
      for (final code in [
        'NETWORK_ERROR',
        'CLIENT_TIMEOUT',
        'SOURCE_TIMEOUT',
        'SOURCE_UNAVAILABLE',
      ]) {
        final feedback = _from(code, status: 503);
        expect(feedback.isConnectivity, isTrue, reason: code);
      }
      expect(_from('NETWORK_ERROR').kind, SearchFeedbackKind.offline);
      expect(_from('CLIENT_TIMEOUT').kind, SearchFeedbackKind.timeout);
      expect(_from('SOURCE_UNAVAILABLE').kind, SearchFeedbackKind.unavailable);
    });

    test('erro inesperado não é culpa do código nem some em silêncio', () {
      final feedback = SearchFeedback.fromError(StateError('x'), '30402');
      expect(feedback.kind, SearchFeedbackKind.unavailable);
      expect(feedback.isConnectivity, isTrue);
    });

    test('código inválido e ponto inexistente culpam o código', () {
      expect(SearchFeedback.invalidCode.isConnectivity, isFalse);
      expect(_from('SOURCE_INVALID_RESPONSE').isConnectivity, isFalse);
      expect(_from('INVALID_STOP').isConnectivity, isFalse);
      expect(_from('X', status: 404).kind, SearchFeedbackKind.notFound);
      expect(_from('X', status: 404).isConnectivity, isFalse);
    });

    test('a mensagem técnica do Worker nunca chega ao texto', () {
      final feedback = SearchFeedback.fromError(
        const ApiException(
          code: 'SOURCE_UNAVAILABLE',
          message: 'RMTC arrivals source returned HTTP 502.',
          retryable: true,
        ),
        '30402',
      );
      expect('${feedback.title} ${feedback.message}', isNot(contains('HTTP')));
      expect('${feedback.title} ${feedback.message}', isNot(contains('RMTC')));
    });
  });
}
