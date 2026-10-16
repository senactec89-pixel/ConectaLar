import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../utils/constants.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiBinaryResponse {
  const ApiBinaryResponse({
    required this.bytes,
    required this.contentType,
    this.fileName,
  });

  final Uint8List bytes;
  final String contentType;
  final String? fileName;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _accessToken;
  int _sessionRevision = 0;
  Future<void> Function()? onSessionExpired;

  bool get autenticado => _accessToken != null;

  String absoluteUrl(String endpoint) => _buildUri(endpoint, null).toString();

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

  Future<ApiBinaryResponse> getBinary(String endpoint) async {
    final uri = _buildUri(endpoint, null);
    final requestToken = _accessToken;
    final requestRevision = _sessionRevision;
    final request = http.Request('GET', uri)..headers['Accept'] = '*/*';

    if (requestToken != null) {
      request.headers['Authorization'] = 'Bearer $requestToken';
    }

    final timeout = Duration(seconds: AppConstants.apiTimeoutSeconds);
    final http.Response response;
    try {
      final streamedResponse = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'A resposta demorou. Verifique sua conexão e tente novamente.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Não foi possível conectar. Verifique sua conexão e tente novamente.',
      );
    }

    if (response.statusCode == 401 &&
        requestToken != null &&
        requestRevision == _sessionRevision) {
      await onSessionExpired?.call();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _mensagemErroBinario(response) ??
            _mensagemPadraoStatus(response.statusCode),
        statusCode: response.statusCode,
      );
    }

    return ApiBinaryResponse(
      bytes: response.bodyBytes,
      contentType:
          response.headers['content-type']?.split(';').first.trim() ??
          'application/octet-stream',
      fileName: _fileNameFromDisposition(
        response.headers['content-disposition'],
      ),
    );
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
    final http.Response response;
    try {
      final streamedResponse = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'A resposta demorou. Verifique sua conexão e tente novamente.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Não foi possível conectar. Verifique sua conexão e tente novamente.',
      );
    }

    final path = endpoint.replaceFirst(RegExp(r'^/+'), '');
    final Object? decoded;
    try {
      decoded = response.body.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode == 401 &&
          requestToken != null &&
          requestRevision == _sessionRevision &&
          !_erroAutenticacaoTratavel(path, null)) {
        await onSessionExpired?.call();
      }
      throw ApiException(
        'Não foi possível carregar os dados. Tente novamente.',
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'Não foi possível carregar os dados. Tente novamente.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 401 &&
        requestToken != null &&
        requestRevision == _sessionRevision &&
        !_erroAutenticacaoTratavel(path, decoded['code'])) {
      await onSessionExpired?.call();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message'];
      throw ApiException(
        message is String
            ? message
            : _mensagemPadraoStatus(response.statusCode),
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

  String _mensagemPadraoStatus(int statusCode) {
    return switch (statusCode) {
      400 => 'Confira os dados enviados e tente novamente.',
      401 => 'Sua sessão expirou. Entre novamente.',
      403 => 'Você não tem permissão para esta ação.',
      404 => 'Este conteúdo não está disponível.',
      409 => 'O conteúdo mudou. Atualize a tela e tente novamente.',
      429 =>
        'Muitas tentativas em pouco tempo. Aguarde um instante e tente novamente.',
      >= 500 =>
        'Não foi possível concluir agora. Tente novamente em instantes.',
      _ => 'Não foi possível concluir. Tente novamente.',
    };
  }

  bool _erroAutenticacaoTratavel(String path, Object? code) {
    if (const {'auth/login', 'auth/cadastro', 'auth/logout'}.contains(path)) {
      return true;
    }
    return code == 'SENHA_ATUAL_INVALIDA';
  }

  String? _mensagemErroBinario(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('application/json')) return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  String? _fileNameFromDisposition(String? value) {
    if (value == null) return null;
    final match = RegExp(r'filename="([^"]+)"').firstMatch(value);
    return match?.group(1);
  }
}
