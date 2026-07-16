
class EnvConfig {
  // Prevent instantiation
  EnvConfig._();

  // Google Sign-In Server Client ID
  // TODO: Move this to a secure build-time configuration or .env file in the future
  static const String googleServerClientId = '393292496655-l2m1k813boj72p74e9a7tkorm52hu8al.apps.googleusercontent.com';

  // Secure Storage Keys
  static const String secureKeyStorageKey = 'hive_encryption_key';
  static const String userTokenKey = 'user_auth_token';
  static const String llmApiKeyStorageKey = 'llm_api_key';

  /// Managed AI proxy (Phase C). When set to your deployed Firebase Cloud
  /// Function URL, the app calls the proxy (which holds the provider key
  /// server-side + enforces auth/quota) instead of a direct provider key.
  /// Override at build time: --dart-define=AI_PROXY_URL=https://…/aiProxy
  static const String aiProxyUrl =
      String.fromEnvironment('AI_PROXY_URL', defaultValue: '');
}
