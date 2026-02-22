import 'package:flutter/foundation.dart';

/// Ad placement types
enum AdPlacement {
  dashboardBanner,
  reminderListNative,
  financeListNative,
  interstitialAfterDismiss,
  rewardedUnlockFeature,
}

/// Ad Service - Manages all ad display
/// 
/// TODO: Integrate with actual ad SDK (AdMob, Facebook, Unity)
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();
  
  bool _isInitialized = false;
  int _interstitialCounter = 0;
  DateTime? _lastInterstitialTime;
  
  // Configuration
  static const int _interstitialsPerDay = 3;
  static const int _actionsBeforeInterstitial = 5;
  static const Duration _minInterstitialInterval = Duration(minutes: 5);

  /// Initialize ad service
  Future<void> init() async {
    if (_isInitialized) return;
    
    // TODO: Initialize actual ad SDKs here
    // await MobileAds.instance.initialize();
    
    _isInitialized = true;
    debugPrint('AdService initialized. Ads enabled: true');
  }

  /// Check if ads should be shown
  bool get shouldShowAds => true;

  /// Check if a specific ad placement should be shown
  bool shouldShowAdAt(AdPlacement placement) {
    if (!shouldShowAds) return false;
    
    switch (placement) {
      case AdPlacement.dashboardBanner:
        return true;
      case AdPlacement.reminderListNative:
        return true;
      case AdPlacement.financeListNative:
        return true;
      case AdPlacement.interstitialAfterDismiss:
        return _canShowInterstitial();
      case AdPlacement.rewardedUnlockFeature:
        return true; // Always available for free users
    }
  }

  /// Check if interstitial ad can be shown
  bool _canShowInterstitial() {
    if (!shouldShowAds) return false;
    
    // Check daily limit
    if (_interstitialCounter >= _interstitialsPerDay) {
      return false;
    }
    
    // Check time interval
    if (_lastInterstitialTime != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialTime!);
      if (elapsed < _minInterstitialInterval) {
        return false;
      }
    }
    
    return true;
  }

  /// Track an action that may trigger interstitial
  int _actionCounter = 0;
  bool trackActionAndCheckInterstitial() {
    if (!shouldShowAds) return false;
    
    _actionCounter++;
    if (_actionCounter >= _actionsBeforeInterstitial && _canShowInterstitial()) {
      _actionCounter = 0;
      return true;
    }
    return false;
  }

  /// Show banner ad (returns widget data)
  Future<Map<String, dynamic>?> loadBannerAd() async {
    if (!shouldShowAds) return null;
    
    // TODO: Load actual banner ad
    // final bannerAd = BannerAd(
    //   adUnitId: 'ca-app-pub-xxx/xxx',
    //   size: AdSize.banner,
    //   ...
    // );
    // await bannerAd.load();
    
    return {
      'type': 'banner',
      'width': 320.0,
      'height': 50.0,
      'isLoaded': true,
    };
  }

  /// Show interstitial ad
  Future<bool> showInterstitial() async {
    if (!_canShowInterstitial()) return false;
    
    // TODO: Show actual interstitial ad
    // final interstitialAd = InterstitialAd(
    //   adUnitId: 'ca-app-pub-xxx/xxx',
    //   ...
    // );
    // await interstitialAd.show();
    
    _interstitialCounter++;
    _lastInterstitialTime = DateTime.now();
    
    debugPrint('Interstitial ad shown (${_interstitialCounter}/$_interstitialsPerDay today)');
    return true;
  }

  /// Show rewarded video ad
  /// Returns true if user watched the full ad
  Future<bool> showRewardedAd({
    required String featureToUnlock,
    required Function(String) onRewarded,
  }) async {
    // TODO: Show actual rewarded ad
    // final rewardedAd = RewardedAd(
    //   adUnitId: 'ca-app-pub-xxx/xxx',
    //   ...
    // );
    // await rewardedAd.show();
    
    // Simulate successful reward
    onRewarded(featureToUnlock);
    debugPrint('Rewarded ad completed for: $featureToUnlock');
    return true;
  }

  /// Load native ad for list integration
  Future<Map<String, dynamic>?> loadNativeAd(AdPlacement placement) async {
    if (!shouldShowAdAt(placement)) return null;
    
    // TODO: Load actual native ad
    return {
      'type': 'native',
      'headline': 'Sponsored',
      'body': 'Upgrade to Premium for ad-free experience',
      'cta': 'Learn More',
      'isLoaded': true,
    };
  }

  /// Reset daily counters (call at midnight)
  void resetDailyCounters() {
    _interstitialCounter = 0;
    _actionCounter = 0;
    debugPrint('Ad counters reset');
  }

  /// Get ad statistics
  Map<String, dynamic> getStats() {
    return {
      'adsEnabled': shouldShowAds,
      'interstitialsShownToday': _interstitialCounter,
      'interstitialsRemaining': _interstitialsPerDay - _interstitialCounter,
      'actionsUntilNextInterstitial': _actionsBeforeInterstitial - _actionCounter,
    };
  }
}

/// Temporary unlock manager for rewarded ads
class TemporaryUnlockManager {
  static final TemporaryUnlockManager _instance = TemporaryUnlockManager._internal();
  factory TemporaryUnlockManager() => _instance;
  TemporaryUnlockManager._internal();

  final Map<String, DateTime> _unlocks = {};
  static const Duration _unlockDuration = Duration(hours: 24);

  /// Check if a feature is temporarily unlocked
  bool isUnlocked(String feature) {
    final expiry = _unlocks[feature];
    if (expiry == null) return false;
    
    if (DateTime.now().isAfter(expiry)) {
      _unlocks.remove(feature);
      return false;
    }
    return true;
  }

  /// Unlock a feature temporarily
  void unlock(String feature) {
    _unlocks[feature] = DateTime.now().add(_unlockDuration);
    debugPrint('Feature "$feature" unlocked until ${_unlocks[feature]}');
  }

  /// Get remaining time for a feature
  Duration? getRemainingTime(String feature) {
    final expiry = _unlocks[feature];
    if (expiry == null) return null;
    
    final remaining = expiry.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Get all active unlocks
  Map<String, Duration> getActiveUnlocks() {
    final active = <String, Duration>{};
    _unlocks.forEach((feature, expiry) {
      final remaining = expiry.difference(DateTime.now());
      if (!remaining.isNegative) {
        active[feature] = remaining;
      }
    });
    return active;
  }
}
