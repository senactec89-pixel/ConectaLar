import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AuthService extends ChangeNotifier {
  AuthService(this._api, {this.persistirSessao = true});

  static const _sessionKey = 'conectalar.auth.session.v1';

  final ApiService _api;
  final bool persistirSessao;
  Map<String, dynamic>? _usuarioAtual;
  bool _sessaoExpirada = false;

  Map<String, dynamic>? get usuarioAtual => _usuarioAtual;
  bool get autenticado => _api.autenticado;
  bool get sessaoExpirada => _sessaoExpirada;

  Future<void> encerrarSessaoExpirada() async {
    if (!autenticado) return;
    _usuarioAtual = null;
    _api.definirToken(null);
    _sessaoExpirada = true;
    notifyListeners();
    if (persistirSessao) {
      final prefs = await SharedPreferences.getInstance();
      // Uma nova entrada pode acontecer enquanto o armazenamento é obtido.
      if (!autenticado) await prefs.remove(_sessionKey);
    }
  }

  Future<void> inicializarSessao() async {
    if (!persistirSessao) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await prefs.remove(_sessionKey);
        return;
      }

      final accessToken = decoded['accessToken'];
      final usuario = decoded['usuario'];
      if (accessToken is! String || usuario is! Map<String, dynamic>) {
        await prefs.remove(_sessionKey);
        return;
      }

      _api.definirToken(accessToken);
      _usuarioAtual = usuario;
    } on FormatException {
      await prefs.remove(_sessionKey);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String senha,
  }) async {
    final response = await _api.post(
      'auth/login',
      body: {'email': email, 'senha': senha},
    );
    if (response['mfaRequired'] == true) {
      final token = response['mfaToken'];
      if (token is String && token.isNotEmpty) {
        throw MfaRequiredException(token);
      }
    }
    await _registrarSessao(response);
    return response;
  }

  Future<Map<String, dynamic>> confirmarLoginMfa({
    required String mfaToken,
    required String codigo,
  }) async {
    final response = await _api.post(
      'auth/login/mfa',
      body: {'mfaToken': mfaToken, 'codigo': codigo},
    );
    await _registrarSessao(response);
    return response;
  }

  Future<Map<String, dynamic>> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required String tipo,
    String? telefone,
  }) async {
    final response = await _api.post(
      'auth/cadastro',
      body: {
        'nome': nome,
        'email': email,
        'senha': senha,
        'tipo': tipo,
        if (telefone != null && telefone.isNotEmpty) 'telefone': telefone,
      },
    );
    await _registrarSessao(response);
    return response;
  }

  Future<Map<String, dynamic>> solicitarRecuperacaoSenha({
    required String email,
  }) {
    return _api.post('auth/senha/recuperacao', body: {'email': email});
  }

  Future<Map<String, dynamic>> confirmarRecuperacaoSenha({
    required String token,
    required String novaSenha,
  }) {
    return _api.post(
      'auth/senha/recuperacao/confirmar',
      body: {'token': token, 'novaSenha': novaSenha},
    );
  }

  Future<Map<String, dynamic>> alterarSenha({
    required String senhaAtual,
    required String novaSenha,
  }) {
    return _api.patch(
      'auth/senha',
      body: {'senhaAtual': senhaAtual, 'novaSenha': novaSenha},
    );
  }

  Future<Map<String, dynamic>> logout() async {
    Map<String, dynamic> response = {'ok': true};
    if (_api.autenticado) {
      try {
        response = await _api.post('auth/logout');
      } catch (_) {
        // Mesmo se a API estiver indisponivel, a sessao local precisa sair.
      }
    }
    _usuarioAtual = null;
    _api.definirToken(null);
    _sessaoExpirada = false;
    notifyListeners();
    if (persistirSessao) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    }
    return response;
  }

  Future<void> _registrarSessao(Map<String, dynamic> response) async {
    final token = response['token'];
    final usuario = response['usuario'];
    String? accessToken;
    if (token is Map<String, dynamic>) {
      final tokenValue = token['accessToken'];
      if (tokenValue is String) {
        accessToken = tokenValue;
        _api.definirToken(tokenValue);
      }
    }
    if (usuario is Map<String, dynamic>) {
      _usuarioAtual = usuario;
    }
    _sessaoExpirada = false;
    notifyListeners();
    if (persistirSessao && accessToken != null && _usuarioAtual != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _sessionKey,
        jsonEncode({'accessToken': accessToken, 'usuario': _usuarioAtual}),
      );
    }
  }
}

class MfaRequiredException implements Exception {
  const MfaRequiredException(this.mfaToken);

  final String mfaToken;
}
