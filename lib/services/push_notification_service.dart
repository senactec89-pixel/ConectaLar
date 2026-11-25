import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';
import 'firebase_push_options.dart';

class PushNotificationService {
  PushNotificationService(this._api);

  static const _channel = AndroidNotificationChannel(
    'conectalar_updates',
    'Atualizacoes do ConectaLar',
    description: 'Avisos sobre pedidos, propostas e atendimentos.',
    importance: Importance.high,
  );

  final ApiService _api;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _messaging;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  String? _currentToken;
  bool _initialized = false;
  bool _sessionActive = false;
  bool _deviceRegistered = false;
  bool _pendingOpen = false;
  VoidCallback? _onNotificationTap;

  bool get disponivel => _initialized;

  set onNotificationTap(VoidCallback? callback) {
    _onNotificationTap = callback;
    if (_pendingOpen && callback != null) {
      _pendingOpen = false;
      callback();
    }
  }

  Future<void> inicializar() async {
    if (_initialized) return;
    final options = FirebasePushOptions.currentPlatform;
    if (options == null) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      final messaging = FirebaseMessaging.instance;
      if (!await messaging.isSupported()) return;

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (_) => _abrirCentral(),
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      _messaging = messaging;
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _mostrarEmPrimeiroPlano,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (_) => _abrirCentral(),
      );
      // The API Admin SDK sends to FCM registration tokens, not Firebase
      // Installation IDs exposed by the newer onRegistered stream.
      // ignore: deprecated_member_use
      _tokenSubscription = messaging.onTokenRefresh.listen((token) {
        _sincronizarTokenAtualizado(token).ignore();
      });
      _initialized = true;

      final mensagemInicial = await messaging.getInitialMessage();
      if (mensagemInicial != null) _abrirCentral();
    } catch (_) {
      debugPrint('Push notifications initialization failed.');
    }
  }

  Future<void> atualizarSessao({required bool ativa}) async {
    if (ativa == _sessionActive) {
      if (ativa && _initialized) await habilitarParaSessaoAtual();
      return;
    }
    _sessionActive = ativa;
    if (!ativa) {
      await revogarDispositivoDaSessao();
      try {
        // Keep token semantics aligned with the server's FCM registration-token
        // store; unregister() exposes an Installation ID instead.
        // ignore: deprecated_member_use
        await _messaging?.deleteToken();
      } catch (_) {
        // A sessao local ja foi encerrada; o token expira/sera limpo no servidor.
      }
      _currentToken = null;
      _deviceRegistered = false;
      return;
    }
    if (_initialized) await habilitarParaSessaoAtual();
  }

  Future<bool> habilitarParaSessaoAtual({bool pedirPermissao = false}) async {
    final messaging = _messaging;
    if (!_initialized || !_sessionActive || messaging == null) return false;

    try {
      var settings = await messaging.getNotificationSettings();
      if (pedirPermissao &&
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return false;
      }

      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return false;
      _currentToken = token;
      return await _registrarToken(token);
    } catch (_) {
      debugPrint('Push notifications registration failed.');
      return false;
    }
  }

  Future<void> revogarDispositivoDaSessao() async {
    final token = _currentToken;
    if (token == null || !_deviceRegistered || !_api.autenticado) return;
    try {
      await _api.post(
        'notificacoes/me/dispositivos/revogar',
        body: {'token': token},
      );
      _deviceRegistered = false;
    } catch (_) {
      // O token sera invalidado localmente ao encerrar a sessao.
    }
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }

  Future<bool> _registrarToken(String token) async {
    if (!_api.autenticado) return false;
    try {
      await _api.post(
        'notificacoes/me/dispositivos',
        body: {'token': token, 'plataforma': _plataforma},
      );
      _deviceRegistered = true;
      return true;
    } catch (_) {
      debugPrint('Push notifications device registration failed.');
      return false;
    }
  }

  Future<void> _sincronizarTokenAtualizado(String token) async {
    final messaging = _messaging;
    if (!_sessionActive || !_initialized || messaging == null) return;

    try {
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      final previousToken = _currentToken;
      if (_deviceRegistered &&
          previousToken != null &&
          previousToken != token) {
        try {
          await _api.post(
            'notificacoes/me/dispositivos/revogar',
            body: {'token': previousToken},
          );
        } catch (_) {
          // The server removes stale tokens after Firebase rejects delivery.
        }
      }
      _currentToken = token;
      await _registrarToken(token);
    } catch (_) {
      debugPrint('Push notification token refresh failed.');
    }
  }

  String get _plataforma => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    _ => 'android',
  };

  Future<void> _mostrarEmPrimeiroPlano(RemoteMessage message) async {
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null || body == null) return;
    final payload = jsonEncode({
      'notificationId': message.data['notificationId'],
    });
    await _local.show(
      id:
          (message.messageId?.hashCode ??
              DateTime.now().millisecondsSinceEpoch) &
          0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  void _abrirCentral() {
    final callback = _onNotificationTap;
    if (callback == null) {
      _pendingOpen = true;
    } else {
      callback();
    }
  }
}
