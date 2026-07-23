import 'clean_storage_service.dart';

/// Entitlement gate for "DailyMinder Plus". This is the scaffold the BA flagged
/// as the #1 business move (a subscription; ads are only a bridge). The
/// entitlement is a persisted flag so feature-gates can read it synchronously
/// today; a real store integration (StoreKit / Play Billing, e.g. via
/// RevenueCat) later just needs to call [setActive] on a verified purchase —
/// no call-site changes.
class PremiumService {
  const PremiumService._();

  static const String _key = 'premium_active';

  /// True when the user has DailyMinder Plus. Reads the loaded pref cache.
  static bool get isActive =>
      CleanStorageService.getAppPreference(_key, false) == true;

  /// Set by a verified purchase/restore (or the dev simulate toggle).
  static Future<void> setActive(bool value) =>
      CleanStorageService.setAppPreference(_key, value);

  /// The Plus feature list (single source of truth for the paywall + gates).
  static const List<(String, String)> features = [
    ('Unlimited medicines', 'Track your whole regimen — no cap'),
    ('Advanced insights & reports', 'Trends, comparisons & a doctor-ready PDF'),
    ('Caregiver sharing', 'Let a family member see doses & get alerts'),
    ('Refill prediction', 'Know before you run out'),
    ('Ad-free', 'A calmer, cleaner app'),
  ];
}
