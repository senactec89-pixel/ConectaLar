import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

abstract interface class GoogleIdentityClient {
  bool get configured;

  bool get supportsAuthenticate;

  Stream<String> get idTokens;

  Future<void> initialize();

  Future<String> authenticate();

  Future<void> signOut();
}

class PluginGoogleIdentityClient implements GoogleIdentityClient {
  static const _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  final _idTokenController = StreamController<String>.broadcast();
  Future<void>? _initialization;

  @override
  bool get configured {
    if (_webClientId.trim().isEmpty) return false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return _iosClientId.trim().isNotEmpty;
    }
    return true;
  }

  @override
  bool get supportsAuthenticate =>
      configured && GoogleSignIn.instance.supportsAuthenticate();

  @override
  Stream<String> get idTokens => _idTokenController.stream;

  @override
  Future<void> initialize() {
    if (!configured) {
      throw const GoogleIdentityException(
        'O login com Google ainda nao foi configurado neste aplicativo.',
      );
    }
    return _initialization ??= _initializePlugin();
  }

  Future<void> _initializePlugin() async {
    try {
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb || defaultTargetPlatform == TargetPlatform.iOS
            ? (kIsWeb ? _webClientId : _iosClientId)
            : null,
        serverClientId: kIsWeb ? null : _webClientId,
      );
      if (kIsWeb) {
        GoogleSignIn.instance.authenticationEvents.listen(
          (event) {
            if (event is GoogleSignInAuthenticationEventSignIn) {
              final token = event.user.authentication.idToken;
              if (token != null && token.isNotEmpty) {
                _idTokenController.add(token);
              } else {
                _idTokenController.addError(
                  const GoogleIdentityException(
                    'O Google nao retornou uma credencial valida.',
                  ),
                );
              }
            }
          },
          onError: (Object error) =>
              _idTokenController.addError(_translateError(error)),
        );
      }
    } catch (error) {
      throw _translateError(error);
    }
  }

  @override
  Future<String> authenticate() async {
    await initialize();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const GoogleIdentityException(
        'Use o botao oficial do Google exibido nesta pagina.',
      );
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const GoogleIdentityException(
          'O Google nao retornou uma credencial valida.',
        );
      }
      return token;
    } catch (error) {
      throw _translateError(error);
    }
  }

  @override
  Future<void> signOut() async {
    if (_initialization == null) return;
    try {
      await _initialization;
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // A sessao do ConectaLar deve sair mesmo se o SDK Google falhar.
    }
  }

  GoogleIdentityException _translateError(Object error) {
    if (error is GoogleIdentityException) return error;
    if (error is GoogleSignInException) {
      return switch (error.code) {
        GoogleSignInExceptionCode.canceled =>
          const GoogleIdentityCanceledException(),
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          const GoogleIdentityException(
            'O login com Google nao esta configurado corretamente.',
          ),
        _ => const GoogleIdentityException(
          'Nao foi possivel entrar com o Google. Tente novamente.',
        ),
      };
    }
    return const GoogleIdentityException(
      'Nao foi possivel entrar com o Google. Tente novamente.',
    );
  }
}

class GoogleIdentityException implements Exception {
  const GoogleIdentityException(this.message);

  final String message;
}

class GoogleIdentityCanceledException extends GoogleIdentityException {
  const GoogleIdentityCanceledException()
    : super('A entrada com o Google foi cancelada.');
}
