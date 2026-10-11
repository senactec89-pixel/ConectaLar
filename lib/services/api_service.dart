import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/constants.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _accessToken;
  int _sessionRevision = 0;
  Future<void> Function()? onSessionExpired;

  bool get autenticado => _accessToken != null;

  void definirToken(String? token) {
    _sessionRevision++;
    _accessToken = token == null || token.trim().isEmpty ? null : token.trim();
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) {
    return _request('GET', endpoint, queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) {
    return _request('POST', endpoint, body: body);
  }

  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) {
    return _request('PUT', endpoint, body: body);
  }

  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) {
    return _request('PATCH', endpoint, body: body);
  }

  Future<Map<String, dynamic>> delete(String endpoint) {
    return _request('DELETE', endpoint);
  }

  void close() => _client.close();

  Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final requestToken = _accessToken;
    final requestRevision = _sessionRevision;
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';

    if (requestToken != null) {
      request.headers['Authorization'] = 'Bearer $requestToken';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final timeout = Duration(seconds: AppConstants.apiTimeoutSeconds);
    final streamedResponse = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(
      streamedResponse,
    ).timeout(timeout);

    final path = endpoint.replaceFirst(RegExp(r'^/+'), '');
    if (response.statusCode == 401 &&
        requestToken != null &&
        requestRevision == _sessionRevision &&
        !const {'auth/login', 'auth/cadastro', 'auth/logout'}.contains(path)) {
      await onSessionExpired?.call();
    }

    final Object? decoded;
    try {
      decoded = response.body.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        'A API retornou uma resposta invalida.',
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'A API retornou uma resposta invalida.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message'];
      throw ApiException(
        message is String ? message : 'Nao foi possivel concluir a requisicao.',
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  Uri _buildUri(String endpoint, Map<String, String>? queryParameters) {
    final baseUrl = AppConstants.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final path = endpoint.replaceFirst(RegExp(r'^/+'), '');
    final uri = Uri.parse('$baseUrl/$path');
    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }
}
