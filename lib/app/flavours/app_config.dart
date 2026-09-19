import 'package:customer/core/data/http/client/api_client_config.dart';

class AppConfig {
  const AppConfig();

  String get apiBaseUrl => const String.fromEnvironment('API_BASE_URL');
  String get apiVersion => const String.fromEnvironment('API_VERSION', defaultValue: 'v1');
  bool get debug => const bool.fromEnvironment('APP_DEBUG');
  String get defaultLocale => const String.fromEnvironment('DEFAULT_LOCALE', defaultValue: 'en');
  bool get isProduction => !debug;

  ApiClientConfig getApiClientConfig() => ApiClientConfig(
        baseUrl: apiBaseUrl,
        apiVersion: apiVersion,
        isDebug: debug,
      );
}
