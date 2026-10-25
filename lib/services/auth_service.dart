import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'session_storage.dart';

class AuthService extends ChangeNotifier {
  AuthService(
    this._api, {
    this.persistirSessao = true,
    SessionStorage? sessionStorage,
    Future<void> Function()? onFederatedLogout,
  }) : _sessionStorage = sessionStorage ?? SecureSessionStorage(),
       _onFederatedLogout = onFederatedLogout;

  static const _sessionKey = 'conectalar.auth.session.v1';

  final ApiService _api;
  final SessionStorage _sessionStorage;
  final Future<void> Function()? _onFederatedLogout;
  final bool persistirSessao;
  Map<String, dynamic>? _usuarioAtual;
  String? _accessTokenAtual;
  bool _sessaoExpirada = false;

  Map<String, dynamic>? get usuarioAtual => _usuarioAtual;
  bool get autenticado => _api.autenticado;
  bool get sessaoExpirada => _sessaoExpirada;
  bool get emailVerificado => _usuarioAtual?['emailVerificado'] != false;
  // Sessoes legadas nao tinham este campo; a API continua sendo a autoridade
  // e responde TERMOS_NAO_ACEITOS quando a versao vigente estiver pendente.
  bool get termosAceitos => _usuarioAtual?['termosAceitos'] != false;

  Future<void> encerrarSessaoExpirada() async {
    if (!autenticado) return;
    _usuarioAtual = null;
    _accessTokenAtual = null;
    _api.definirToken(null);
    _sessaoExpirada = true;
    notifyListeners();
    if (persistirSessao) {
      // Uma nova entrada pode acontecer enquanto o armazenamento é obtido.
      if (!autenticado) await _sessionStorage.delete(_sessionKey);
    }
  }

  Future<void> inicializarSessao() async {
    if (!persistirSessao) return;
    final raw = await _sessionStorage.read(_sessionKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await _sessionStorage.delete(_sessionKey);
        return;
      }

      final accessToken = decoded['accessToken'];
      final usuario = decoded['usuario'];
      if (accessToken is! String || usuario is! Map<String, dynamic>) {
        await _sessionStorage.delete(_sessionKey);
        return;
      }

      _api.definirToken(accessToken);
      _accessTokenAtual = accessToken;
      _usuarioAtual = usuario;
    } on FormatException {
      await _sessionStorage.delete(_sessionKey);
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
    if (response['mfaSetupRequired'] == true) {
      final token = response['mfaSetupToken'];
      if (token is String && token.isNotEmpty) {
        throw MfaSetupRequiredException(token);
      }
    }
    await _registrarSessao(response);
    return response;
  }

  Future<Map<String, dynamic>> loginGoogle({
    required String idToken,
    String? tipo,
    String? senha,
    bool aceitouTermos = false,
    String? versaoTermos,
  }) async {
    final response = await _api.post(
      'auth/google',
      body: {
        'idToken': idToken,
        'tipo': ?tipo,
        'senha': ?senha,
        if (tipo != null) 'aceitouTermos': aceitouTermos,
        if (tipo != null) 'versaoTermos': versaoTermos,
      },
    );
    if (response['cadastroNecessario'] == true) return response;
    if (response['mfaRequired'] == true) {
      final token = response['mfaToken'];
      if (token is String && token.isNotEmpty) {
        throw MfaRequiredException(token);
      }
    }
    if (response['mfaSetupRequired'] == true) {
      final token = response['mfaSetupToken'];
      if (token is String && token.isNotEmpty) {
        throw MfaSetupRequiredException(token);
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

  Future<Map<String, dynamic>> iniciarConfiguracaoMfaAdmin({
    required String setupToken,
  }) => _api.post(
    'auth/admin-mfa/setup',
    body: {'setupToken': setupToken},
  );

  Future<Map<String, dynamic>> confirmarConfiguracaoMfaAdmin({
    required String setupToken,
    required String codigo,
  }) async {
    final response = await _api.post(
      'auth/admin-mfa/confirmar',
      body: {'setupToken': setupToken, 'codigo': codigo},
    );
    await _registrarSessao(response);
    return response;
  }

  Future<Map<String, dynamic>> aceitarConviteAdmin({
    required String token,
    required String senha,
    required String versaoTermos,
  }) => _api.post(
    'auth/admin-convites/aceitar',
    body: {
      'token': token,
      'senha': senha,
      'aceitouTermos': true,
      'versaoTermos': versaoTermos,
    },
  );

  Future<Map<String, dynamic>> statusMfaAdmin() {
    return _api.get('auth/mfa/admin');
  }

  Future<Map<String, dynamic>> iniciarMfaAdmin() {
    return _api.post('auth/mfa/admin/setup');
  }

  Future<Map<String, dynamic>> confirmarMfaAdmin({required String codigo}) {
    return _api.post('auth/mfa/admin/confirmar', body: {'codigo': codigo});
  }

  Future<Map<String, dynamic>> desativarMfaAdmin({
    required String senhaAtual,
    required String codigo,
  }) {
    return _api.post(
      'auth/mfa/admin/desativar',
      body: {'senhaAtual': senhaAtual, 'codigo': codigo},
    );
  }

  /// A API invalida o token anterior depois de alterar o MFA.
  Future<void> encerrarSessaoAposMfa() => _limparSessaoLocal();

  Future<Map<String, dynamic>> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required String tipo,
    required String versaoTermos,
    required bool aceitouTermos,
    String? telefone,
  }) async {
    final response = await _api.post(
      'auth/cadastro',
      body: {
        'nome': nome,
        'email': email,
        'senha': senha,
        'tipo': tipo,
        'versaoTermos': versaoTermos,
        'aceitouTermos': aceitouTermos,
        if (telefone != null && telefone.isNotEmpty) 'telefone': telefone,
      },
    );
    await _registrarSessao(response);
    return response;
  }

  Future<void> marcarTermosPendentes() async {
    if (_usuarioAtual == null || _usuarioAtual?['termosAceitos'] == false) {
      return;
    }
    _usuarioAtual = {..._usuarioAtual!, 'termosAceitos': false};
    await _persistirSessaoAtual();
    notifyListeners();
  }

  Future<void> registrarTermosAceitos(String versao) async {
    if (_usuarioAtual == null) return;
    _usuarioAtual = {
      ..._usuarioAtual!,
      'termosAceitos': true,
      'versaoTermos': versao,
    };
    await _persistirSessaoAtual();
    notifyListeners();
  }

  Future<Map<String, dynamic>> solicitarRecuperacaoSenha({
    required String email,
  }) {
    return _api.post('auth/senha/recuperacao', body: {'email': email});
  }

  Future<Map<String, dynamic>> confirmarRecuperacaoSenha({
    required String email,
    required String token,
    required String novaSenha,
  }) {
    return _api.post(
      'auth/senha/recuperacao/confirmar',
      body: {'email': email, 'token': token, 'novaSenha': novaSenha},
    );
  }

  Future<Map<String, dynamic>> statusVerificacaoEmail() async {
    final response = await _api.get('auth/email/verificacao');
    final emailVerificado = response['emailVerificado'];
    if (_usuarioAtual != null && emailVerificado is bool) {
      _usuarioAtual = {..._usuarioAtual!, 'emailVerificado': emailVerificado};
      await _persistirSessaoAtual();
      notifyListeners();
    }
    return response;
  }

  Future<Map<String, dynamic>> solicitarVerificacaoEmail() {
    return _api.post('auth/email/verificacao/enviar');
  }

  Future<Map<String, dynamic>> confirmarVerificacaoEmail({
    required String codigo,
  }) async {
    final response = await _api.post(
      'auth/email/verificacao/confirmar',
      body: {'codigo': codigo},
    );
    if (response['emailVerificado'] == true && _usuarioAtual != null) {
      _usuarioAtual = {..._usuarioAtual!, 'emailVerificado': true};
      await _persistirSessaoAtual();
      notifyListeners();
    }
    return response;
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

  Future<Map<String, dynamic>> atualizarFotoPerfil({
    required String arquivoBase64,
    required String mimeType,
    String? nomeArquivo,
  }) async {
    final response = await _api.put(
      'auth/me/foto',
      body: {
        'arquivoBase64': arquivoBase64,
        'mimeType': mimeType,
        if (nomeArquivo != null && nomeArquivo.isNotEmpty)
          'nomeArquivo': nomeArquivo,
      },
    );
    await _registrarSessao(response);
    return response;
  }

  Future<Map<String, dynamic>> atualizarDadosPessoais({
    required String nome,
    String? telefone,
  }) async {
    final response = await _api.patch(
      'auth/me/dados',
      body: {'nome': nome, 'telefone': telefone ?? ''},
    );
    await _registrarSessao(response);
    return response;
  }

  Future<Map<String, dynamic>> removerFotoPerfil() async {
    final response = await _api.delete('auth/me/foto');
    await _registrarSessao(response);
    return response;
  }

  Future<Map<String, dynamic>> exportarDados({required String senhaAtual}) {
    return _api.post(
      'privacidade/me/exportacao',
      body: {'senhaAtual': senhaAtual},
    );
  }

  Future<Map<String, dynamic>> excluirConta({
    required String senhaAtual,
    required String confirmacao,
  }) async {
    final response = await _api.post(
      'privacidade/me/exclusao',
      body: {'senhaAtual': senhaAtual, 'confirmacao': confirmacao},
    );
    await _limparSessaoLocal();
    return response;
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
    await _limparSessaoLocal();
    return response;
  }

  Future<void> _limparSessaoLocal() async {
    _usuarioAtual = null;
    _accessTokenAtual = null;
    _api.definirToken(null);
    _sessaoExpirada = false;
    notifyListeners();
    if (persistirSessao) {
      await _sessionStorage.delete(_sessionKey);
    }
    try {
      await _onFederatedLogout?.call();
    } catch (_) {
      // A sessao local ja foi encerrada e nao deve ser restaurada por falha externa.
    }
  }

  Future<void> _registrarSessao(Map<String, dynamic> response) async {
    final token = response['token'];
    final usuario = response['usuario'];
    String? accessToken;
    if (token is Map<String, dynamic>) {
      final tokenValue = token['accessToken'];
      if (tokenValue is String) {
        accessToken = tokenValue;
        _accessTokenAtual = tokenValue;
        _api.definirToken(tokenValue);
      }
    }
    if (usuario is Map<String, dynamic>) {
      _usuarioAtual = usuario;
    }
    _sessaoExpirada = false;
    notifyListeners();
    await _persistirSessaoAtual(accessToken: accessToken);
  }

  Future<void> _persistirSessaoAtual({String? accessToken}) async {
    if (!persistirSessao) return;
    final token = accessToken ?? _accessTokenAtual;
    if (token == null || _usuarioAtual == null) return;
    await _sessionStorage.write(
      _sessionKey,
      jsonEncode({'accessToken': token, 'usuario': _usuarioAtual}),
    );
  }
}

class MfaRequiredException implements Exception {
  const MfaRequiredException(this.mfaToken);

  final String mfaToken;
}

class MfaSetupRequiredException implements Exception {
  const MfaSetupRequiredException(this.setupToken);

  final String setupToken;
}
