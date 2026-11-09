import '../manage_imports.dart';

/// Backend base URL (no trailing slash). Override per build with --dart-define=API_BASE_URL=https://example.com
class AppServerConfig {
  static const String _defaultUrl = 'https://drop.officialkryptonia.workers.dev';
  static const String _fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: _defaultUrl);

  static String get baseUrl => _fromEnv.endsWith('/') ? _fromEnv.substring(0, _fromEnv.length - 1) : _fromEnv;
}
