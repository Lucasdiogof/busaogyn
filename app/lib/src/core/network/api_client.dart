import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = defaultTimeout,
  }) : _client = client ?? http.Client();

  /// O Worker espera até ~6 s por tentativa na RMTC e faz 1 retry; 20 s cobre
  /// esse pior caso com folga de rede móvel sem prender a UI indefinidamente.
  static const defaultTimeout = Duration(seconds: 20);

  static const timeoutCode = 'CLIENT_TIMEOUT';
  static const networkErrorCode = 'NETWORK_ERROR';

  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String> queryParameters = const {},
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: path,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        code: timeoutCode,
        message: 'A consulta demorou mais que o esperado. Tente novamente.',
        retryable: true,
      );
    } on http.ClientException {
      throw const ApiException(
        code: networkErrorCode,
        message: 'Sem conexão com o BusãoGyn. Verifique sua internet.',
        retryable: true,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        code: 'INVALID_RESPONSE',
        message: 'A API retornou uma resposta inválida.',
        retryable: true,
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        code: 'INVALID_RESPONSE',
        message: 'A API retornou um formato inesperado.',
        retryable: true,
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        throw ApiException(
          code: error['code']?.toString() ?? 'API_ERROR',
          message: error['message']?.toString() ?? 'Falha ao consultar a API.',
          retryable: error['retryable'] == true,
          statusCode: response.statusCode,
        );
      }
      throw ApiException(
        code: 'API_ERROR',
        message: 'Falha ao consultar a API.',
        retryable: response.statusCode >= 500,
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  void close() {
    _client.close();
  }
}
