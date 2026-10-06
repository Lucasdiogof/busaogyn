import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String> queryParameters = const {},
  }) async {
    final uri = Uri.parse(baseUrl).replace(
      path: path,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final response = await _client.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );

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
