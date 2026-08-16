
class EnvConfig {
  // Prevent instantiation
  EnvConfig._();

  // Google Sign-In Server Client ID
  // TODO: Move this to a secure build-time configuration or .env file in the future
  static const String googleServerClientId = '393292496655-l2m1k813boj72p74e9a7tkorm52hu8al.apps.googleusercontent.com';

  // Secure Storage Keys
  static const String secureKeyStorageKey = 'hive_encryption_key';
  static const String userTokenKey = 'user_auth_token';

  /// The user's own AI provider key (Groq / Gemini / custom), held in
  /// flutter_secure_storage. The app never ships a key of its own — see
  /// `lib/core/ai/AI_ENGINES.md`.
  static const String llmApiKeyStorageKey = 'llm_api_key';

  /// Public privacy-policy URL.
  ///
  /// Google Play requires this to be **byte-identical** in three places: the
  /// Play Console listing, the in-app link (HealthPrivacyScreen), and the page
  /// itself. A mismatch is a review flag, so this constant is the single
  /// source for the in-app half.
  ///
  /// Empty until the owner publishes the page. [hasPrivacyPolicy] is false
  /// while it is, and the UI hides the link rather than opening a dead URL —
  /// but **the app cannot pass Play review for health permissions until this
  /// is filled in.**
  static const String privacyPolicyUrl = '';

  static bool get hasPrivacyPolicy => privacyPolicyUrl.isNotEmpty;
}
