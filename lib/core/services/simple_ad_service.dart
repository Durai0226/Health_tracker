import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// Ad service — banner + interstitial + rewarded only. Native-in-list ads are
/// deliberately disabled so ads never interleave with health data.
///
/// Production-safety guarantees (see [AdConfig]):
///  • Test ad IDs run in debug ONLY; release uses real IDs or shows nothing.
///  • Ads never load unless GDPR/UMP consent + (iOS) ATT have been resolved.
///  • Sensitive health screens (period/vitals/sleep) carry no ads.
class SimpleAdService {
  static final SimpleAdService _instance = SimpleAdService._internal();
  factory SimpleAdService() => _instance;
  SimpleAdService._internal();

  bool _isInitialized = false;

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  // Ad frequency tracking
  int _interstitialCount = 0;
  DateTime? _lastInterstitialTime;
  int _reminderDismissalCount = 0;

  // Daily limits
  static const int _maxInterstitialsPerDay = 6;
  static const int _minInterstitialInterval = 4; // hours
  static const int _reminderDismissalsBeforeAd = 5;

  Future<void> init() async {
    if (_isInitialized) return;
    if (!AdConfig.available) {
      debugPrint(
          '🎯 SimpleAdService: ads unavailable (no real ad IDs in this build) — skipping.');
      return;
    }

    debugPrint('🎯 SimpleAdService: Initializing…');
    try {
      // 1) GDPR/EEA consent (UMP) + (2) iOS App Tracking Transparency must be
      //    resolved BEFORE requesting any ad.
      await _gatherConsent();
      await _requestAtt();

      await MobileAds.instance.initialize();
      await _loadBannerAd();
      await _preloadInterstitial();
      await _preloadRewarded();

      _isInitialized = true;
      debugPrint('✓ SimpleAdService initialized');
    } catch (e) {
      debugPrint('❌ SimpleAdService initialization failed: $e');
      _isInitialized = false;
    }
  }

  /// Google User Messaging Platform consent gather (required for EEA/UK users).
  /// Best-effort + non-blocking to app startup; ad loads proceed regardless but
  /// personalization respects the collected consent.
  Future<void> _gatherConsent() async {
    try {
      final params = ConsentRequestParameters();
      final completer = _AsyncGate();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
          } catch (_) {}
          completer.done();
        },
        (error) {
          debugPrint('🎯 UMP consent update failed: ${error.message}');
          completer.done();
        },
      );
      await completer.future;
    } catch (e) {
      debugPrint('🎯 UMP consent skipped: $e');
    }
  }

  /// iOS App Tracking Transparency prompt (no-op on Android).
  Future<void> _requestAtt() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('🎯 ATT request skipped: $e');
    }
  }

  // ============================================
  // AD PLACEMENT CHECKS
  // ============================================

  /// Persistent banner on the (neutral) home dashboard.
  bool get shouldShowDashboardBanner => AdConfig.available;

  // Native-in-list ads are disabled so ads never sit beside health data. These
  // remain (returning false) for call-site compatibility.
  bool shouldShowMedicationNativeAd(int index) => false;
  bool shouldShowFinanceNativeAd(int index) => false;
  bool shouldShowNotesNativeAd(int index) => false;
  bool get shouldShowPeriodNativeAd => false; // POLICY: never on menstrual data.

  /// Disabled — native ads are not used (see class doc). Always null.
  Future<NativeAd?> loadNativeAd(String placement) async => null;

  // ============================================
  // INTERSTITIAL AD LOGIC
  // ============================================

  Future<bool> onReminderDismissed() async {
    _reminderDismissalCount++;
    if (_reminderDismissalCount >= _reminderDismissalsBeforeAd) {
      _reminderDismissalCount = 0;
      return await showInterstitialAd('reminder_completion');
    }
    return false;
  }

  Future<bool> onFocusSessionComplete() async =>
      showInterstitialAd('focus_complete');

  Future<bool> onWaterGoalReached() async =>
      showInterstitialAd('water_goal');

  Future<bool> showInterstitialAd(String placement) async {
    if (!AdConfig.available) return false;
    if (!_canShowInterstitial()) {
      debugPrint('🎯 Ad blocked by frequency cap: $placement');
      return false;
    }
    if (_interstitialAd == null) {
      debugPrint('⚠️ No interstitial loaded for: $placement');
      await _preloadInterstitial();
      return false;
    }
    debugPrint('🎯 Showing interstitial: $placement');
    try {
      await _interstitialAd?.show();
      _interstitialCount++;
      _lastInterstitialTime = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('❌ Error showing interstitial: $e');
      return false;
    }
  }

  bool _canShowInterstitial() {
    if (_interstitialCount >= _maxInterstitialsPerDay) return false;
    if (_lastInterstitialTime != null) {
      final hours =
          DateTime.now().difference(_lastInterstitialTime!).inHours;
      if (hours < _minInterstitialInterval) return false;
    }
    return true;
  }

  // ============================================
  // REWARDED VIDEO ADS
  // ============================================

  Future<bool> showRewardedAd({
    required String featureName,
    required void Function(String) onRewarded,
  }) async {
    if (!AdConfig.available) return false;
    if (_rewardedAd == null) {
      debugPrint('⚠️ No rewarded ad loaded');
      await _preloadRewarded();
      return false;
    }
    debugPrint('🎯 Showing rewarded ad: $featureName');
    try {
      await _rewardedAd?.show(
        onUserEarnedReward: (ad, reward) => onRewarded(featureName),
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error showing rewarded ad: $e');
      return false;
    }
  }

  Future<bool> offerRewardedForCoins() async => showRewardedAd(
        featureName: 'focus_coins_2x',
        onRewarded: (_) {},
      );

  // ============================================
  // ANALYTICS & TRACKING
  // ============================================

  Map<String, dynamic> getAdStats() => {
        'interstitials_shown_today': _interstitialCount,
        'last_interstitial': _lastInterstitialTime?.toIso8601String(),
        'reminder_dismissals': _reminderDismissalCount,
        'can_show_interstitial': _canShowInterstitial(),
      };

  void resetDailyCounters() {
    _interstitialCount = 0;
    debugPrint('🎯 Ad counters reset for new day');
  }

  // ============================================
  // AD LOADING
  // ============================================

  Future<void> _loadBannerAd() async {
    final unit = AdConfig.bannerUnitId;
    if (unit == null) return;
    _bannerAd?.dispose();
    _bannerLoaded = false;
    bannerReady.value = false;
    _bannerAd = BannerAd(
      adUnitId: unit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('✓ Banner ad loaded');
          _bannerLoaded = true;
          bannerReady.value = true;
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner ad failed: $error');
          _bannerLoaded = false;
          ad.dispose();
          _bannerAd = null;
          bannerReady.value = false;
        },
      ),
    );
    await _bannerAd?.load();
  }

  BannerAd? get bannerAd => _bannerAd;

  /// True only once the banner has actually loaded. Inserting an [AdWidget]
  /// before load() completes throws "AdWidget requires Ad.load…" and paints a
  /// red error box — the tab-switch glitch. UI must gate on this.
  bool _bannerLoaded = false;
  bool get bannerLoaded => _bannerLoaded;

  /// Fires when [bannerLoaded] changes.
  ///
  /// Without this the banner was a silent state change: `SmartDashboardBanner`
  /// is a StatelessWidget that reads `bannerLoaded` directly, so it stayed a
  /// zero-height SizedBox until some UNRELATED rebuild happened to run — and
  /// on this app that is a tab switch. The result was ~84pt of content
  /// appearing under the user's thumb as they changed tabs, shoving everything
  /// below it down. Listening here decouples the insertion from navigation: it
  /// now appears when the ad actually loads.
  final ValueNotifier<bool> bannerReady = ValueNotifier<bool>(false);

  Future<void> _preloadInterstitial() async {
    final unit = AdConfig.interstitialUnitId;
    if (unit == null) return;
    await InterstitialAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _preloadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _preloadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Interstitial failed to load: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  Future<void> _preloadRewarded() async {
    final unit = AdConfig.rewardedUnitId;
    if (unit == null) return;
    await RewardedAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _preloadRewarded();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _preloadRewarded();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Rewarded failed to load: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    debugPrint('🎯 SimpleAdService disposed');
  }
}

/// Tiny one-shot async gate bridging the callback-style UMP consent API to a
/// single awaitable future.
class _AsyncGate {
  final _c = Completer<void>();
  Future<void> get future => _c.future;
  void done() {
    if (!_c.isCompleted) _c.complete();
  }
}

/// Ad placement identifiers for analytics.
class AdPlacement {
  static const String dashboardBanner = 'dashboard_banner';
  static const String reminderInterstitial = 'reminder_interstitial';
  static const String focusInterstitial = 'focus_interstitial';
  static const String waterInterstitial = 'water_interstitial';
  static const String rewardedVideo = 'rewarded_video';
}
