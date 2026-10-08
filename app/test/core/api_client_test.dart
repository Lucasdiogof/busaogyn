import 'dart:async';

import 'package:busaogyn/src/core/network/api_client.dart';
import 'package:busaogyn/src/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('timeout padrão cobre o pior caso do Worker', () {
    final client = ApiClient(baseUrl: 'https://example.test');
    expect(client.timeout, const Duration(seconds: 20));
  });

  test('requisição que não responde vira ApiException de timeout', () async {
    final never = Completer<http.Response>();
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) => never.future),
      timeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      client.getJson('/v1/health'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', ApiClient.timeoutCode)
            .having((e) => e.retryable, 'retryable', isTrue)
            .having((e) => e.message, 'message', contains('demorou')),
      ),
    );
  });

  test('falha de rede vira ApiException retryable', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) => throw http.ClientException('offline')),
    );

    await expectLater(
      client.getJson('/v1/health'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', ApiClient.networkErrorCode)
            .having((e) => e.retryable, 'retryable', isTrue),
      ),
    );
  });

  test('resposta dentro do prazo segue normal', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => http.Response('{"data":{}}', 200)),
      timeout: const Duration(seconds: 1),
    );

    expect(await client.getJson('/v1/health'), {'data': <String, dynamic>{}});
  });

  test('erro da API mantém código e retryable do Worker', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          '{"error":{"code":"SOURCE_TIMEOUT","message":"x","retryable":true}}',
          503,
        ),
      ),
    );

    await expectLater(
      client.getJson('/v1/stops/1/arrivals'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'SOURCE_TIMEOUT')
            .having((e) => e.statusCode, 'statusCode', 503),
      ),
    );
  });
}
