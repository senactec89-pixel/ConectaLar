import 'package:flutter/foundation.dart';

abstract final class AppConstants {
  static const demoMode = bool.fromEnvironment('CONECTALAR_DEMO');
  static const demoRole = String.fromEnvironment(
    'CONECTALAR_DEMO_ROLE',
    defaultValue: 'cliente',
  );
  static const _apiBaseUrl = String.fromEnvironment('CONECTALAR_API_BASE_URL');
  // Android: alias do computador no emulador. Desktop/web/iOS: loopback.
  // Em aparelho físico ou com outra porta, informe CONECTALAR_API_BASE_URL.
  static String get apiBaseUrl => _apiBaseUrl.isNotEmpty
      ? _apiBaseUrl
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:3012'
      : 'http://127.0.0.1:3012';
  static const apiTimeoutSeconds = 20;
}
