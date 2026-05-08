class Environment {
  Environment._();

  // ── Production URLs ────────────────────────────────────────────────────────
  // Replace with your actual production server URL before release.
  static const _productionApiBaseUrl = 'http://72.61.149.88:3009/api';
  static const _productionSocketBaseUrl = 'http://72.61.149.88:3009';

  // Override via --dart-define during development:
  //   flutter run --dart-define=DRIVER_API_BASE_URL=http://192.168.x.x:3000/api
  static const _apiBaseUrlOverride = String.fromEnvironment(
    'DRIVER_API_BASE_URL',
  );
  static const _socketBaseUrlOverride = String.fromEnvironment(
    'DRIVER_SOCKET_BASE_URL',
  );

  static const apiBaseUrl = _apiBaseUrlOverride != ''
      ? _apiBaseUrlOverride
      : _productionApiBaseUrl;

  static const socketBaseUrl = _socketBaseUrlOverride != ''
      ? _socketBaseUrlOverride
      : _productionSocketBaseUrl;

  static const appName = 'ogas Driver';
  static const appVersion = '1.0.0';
}
