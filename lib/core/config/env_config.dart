
class EnvConfig {
  // Prevent instantiation
  EnvConfig._();

  // Google Sign-In Server Client ID
  // TODO: Move this to a secure build-time configuration or .env file in the future
  static const String googleServerClientId = '393292496655-l2m1k813boj72p74e9a7tkorm52hu8al.apps.googleusercontent.com';

  // Secure Storage Keys
  static const String secureKeyStorageKey = 'hive_encryption_key';
  static const String userTokenKey = 'user_auth_token';
}
