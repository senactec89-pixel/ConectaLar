abstract final class AppConstants {
  static const demoMode = bool.fromEnvironment('CONECTALAR_DEMO');
  // No emulador Android, 10.0.2.2 aponta para o computador local.
  // Para Windows/web local use:
  // flutter run --dart-define=CONECTALAR_API_BASE_URL=http://127.0.0.1:3012
  static const apiBaseUrl = String.fromEnvironment(
    'CONECTALAR_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3012',
  );
  static const apiTimeoutSeconds = 20;
}
