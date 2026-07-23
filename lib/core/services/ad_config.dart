import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Central AdMob ID + policy configuration.
///
/// Two hard rules baked in here:
///  1. **Never ship Google's TEST ad IDs to production.** Debug builds use the
///     official test units; release builds use ONLY the real IDs you provide via
///     `--dart-define` (or leave empty → release simply shows no ads, never a
///     test ad).
///  2. **Ads never appear on sensitive health surfaces** (period/menstrual,
///     vitals, sleep). [sensitiveSurfaces] documents them; call sites must not
///     place ads on those screens (see `SmartDashboardBanner` gating).
///
/// ── How to go live ────────────────────────────────────────────────────────
/// 1. In the AdMob console create the app + ad units, then build with:
///      flutter build appbundle --release \
///        --dart-define=AD_BANNER_ANDROID=ca-app-pub-XXXX/1111 \
///        --dart-define=AD_INTERSTITIAL_ANDROID=ca-app-pub-XXXX/2222 \
///        --dart-define=AD_REWARDED_ANDROID=ca-app-pub-XXXX/3333
///    (and the AD_*_IOS variants for `flutter build ipa`).
/// 2. Replace the AdMob **application IDs** in AndroidManifest.xml and
///    ios/Runner/Info.plist (marked with TODO) — those are compile-time.
class AdConfig {
  const AdConfig._();

  /// Master kill-switch. Flip to false (or gate on a future premium flag) to
  /// pull all ads without touching call sites.
  static bool enabled = true;

  // ── Google's OFFICIAL TEST unit IDs — debug builds only ──
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  // ── Real PRODUCTION unit IDs (supplied at build via --dart-define) ──
  static const _prodBannerAndroid = String.fromEnvironment('AD_BANNER_ANDROID');
  static const _prodBannerIos = String.fromEnvironment('AD_BANNER_IOS');
  static const _prodInterstitialAndroid =
      String.fromEnvironment('AD_INTERSTITIAL_ANDROID');
  static const _prodInterstitialIos =
      String.fromEnvironment('AD_INTERSTITIAL_IOS');
  static const _prodRewardedAndroid =
      String.fromEnvironment('AD_REWARDED_ANDROID');
  static const _prodRewardedIos = String.fromEnvironment('AD_REWARDED_IOS');

  static bool get _ios => !kIsWeb && Platform.isIOS;

  /// Debug → test unit; release → the real per-platform ID (null if unset, so a
  /// misconfigured release shows no ads rather than a test ad).
  static String? _pick(String test, String androidProd, String iosProd) {
    if (kDebugMode) return test;
    final id = _ios ? iosProd : androidProd;
    return id.isEmpty ? null : id;
  }

  static String? get bannerUnitId =>
      _pick(_testBanner, _prodBannerAndroid, _prodBannerIos);
  static String? get interstitialUnitId =>
      _pick(_testInterstitial, _prodInterstitialAndroid, _prodInterstitialIos);
  static String? get rewardedUnitId =>
      _pick(_testRewarded, _prodRewardedAndroid, _prodRewardedIos);

  /// Whether ads can run at all. Debug: always. Release: only when real IDs were
  /// supplied — guaranteeing test ads never reach production.
  static bool get available => enabled && bannerUnitId != null;

  /// Health surfaces that must NEVER carry ads (store policy + user trust).
  static const List<String> sensitiveSurfaces = [
    'period', 'menstrual', 'cycle', 'fertility',
    'vitals', 'blood_pressure', 'glucose', 'sleep',
  ];
}
