import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Simplified Ad Service - Strategic placement for maximum revenue
/// 
/// This service manages ad display across the app with smart frequency
/// capping and strategic placement based on user behavior.
class SimpleAdService {
  static final SimpleAdService _instance = SimpleAdService._internal();
  factory SimpleAdService() => _instance;
  SimpleAdService._internal();

  bool _isInitialized = false;
  
  // Ad instances
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  final Map<String, NativeAd> _nativeAds = {};
  
  // Test Ad Unit IDs (replace with real IDs in production)
  static const String _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testNativeAdUnitId = 'ca-app-pub-3940256099942544/2247696110';
  
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
    
    debugPrint('🎯 SimpleAdService: Initializing...');
    
    try {
      // Initialize AdMob SDK
      await MobileAds.instance.initialize();
      
      // Load initial ads
      await _loadBannerAd();
      await _preloadInterstitial();
      await _preloadRewarded();
      
      _isInitialized = true;
      debugPrint('✓ SimpleAdService initialized with AdMob SDK');
    } catch (e) {
      debugPrint('❌ SimpleAdService initialization failed: $e');
      _isInitialized = false;
    }
  }

  // ============================================
  // AD PLACEMENT CHECKS
  // ============================================

  /// Should show persistent banner ad on dashboard
  bool get shouldShowDashboardBanner => true;

  /// Should show native ad in medication list (every 5th item)
  bool shouldShowMedicationNativeAd(int index) {
    return index > 0 && index % 5 == 0;
  }

  /// Should show native ad in finance list (between accounts)
  bool shouldShowFinanceNativeAd(int index) {
    return index > 0 && index % 3 == 0;
  }

  /// Should show native ad in notes list (every 10th note)
  bool shouldShowNotesNativeAd(int index) {
    return index > 0 && index % 10 == 0;
  }

  /// Should show native ad in period tracking insights
  bool get shouldShowPeriodNativeAd => true;

  // ============================================
  // INTERSTITIAL AD LOGIC
  // ============================================

  /// Track reminder dismissal and show interstitial after threshold
  Future<bool> onReminderDismissed() async {
    _reminderDismissalCount++;
    
    if (_reminderDismissalCount >= _reminderDismissalsBeforeAd) {
      _reminderDismissalCount = 0;
      return await showInterstitialAd('reminder_completion');
    }
    
    return false;
  }

  /// Show interstitial after focus session complete
  Future<bool> onFocusSessionComplete() async {
    return await showInterstitialAd('focus_complete');
  }

  /// Show interstitial when water goal reached
  Future<bool> onWaterGoalReached() async {
    return await showInterstitialAd('water_goal');
  }

  /// Generic interstitial display with frequency capping
  Future<bool> showInterstitialAd(String placement) async {
    if (!_canShowInterstitial()) {
      debugPrint('🎯 Ad blocked by frequency cap: $placement');
      return false;
    }

    if (_interstitialAd == null) {
      debugPrint('⚠️ No interstitial ad loaded for: $placement');
      await _preloadInterstitial();
      return false;
    }

    debugPrint('🎯 Showing interstitial ad: $placement');
    
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

  /// Check if interstitial can be shown based on frequency rules
  bool _canShowInterstitial() {
    // Check daily limit
    if (_interstitialCount >= _maxInterstitialsPerDay) {
      return false;
    }

    // Check time interval
    if (_lastInterstitialTime != null) {
      final hoursSinceLastAd = DateTime.now()
          .difference(_lastInterstitialTime!)
          .inHours;
      
      if (hoursSinceLastAd < _minInterstitialInterval) {
        return false;
      }
    }

    return true;
  }

  // ============================================
  // REWARDED VIDEO ADS
  // ============================================

  /// Show rewarded video ad (user-initiated)
  Future<bool> showRewardedAd({
    required String featureName,
    required Function(String) onRewarded,
  }) async {
    if (_rewardedAd == null) {
      debugPrint('⚠️ No rewarded ad loaded');
      await _preloadRewarded();
      return false;
    }
    
    debugPrint('🎯 Showing rewarded ad for: $featureName');
    
    try {
      await _rewardedAd?.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('✓ User earned reward: ${reward.amount} ${reward.type}');
          onRewarded(featureName);
        },
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error showing rewarded ad: $e');
      return false;
    }
  }

  /// Offer rewarded video for 2x focus coins
  Future<bool> offerRewardedForCoins() async {
    return await showRewardedAd(
      featureName: 'focus_coins_2x',
      onRewarded: (feature) {
        debugPrint('✓ User earned 2x coins from rewarded ad');
      },
    );
  }

  // ============================================
  // ANALYTICS & TRACKING
  // ============================================

  /// Get ad statistics
  Map<String, dynamic> getAdStats() {
    return {
      'interstitials_shown_today': _interstitialCount,
      'last_interstitial': _lastInterstitialTime?.toIso8601String(),
      'reminder_dismissals': _reminderDismissalCount,
      'can_show_interstitial': _canShowInterstitial(),
    };
  }

  /// Reset daily counters (call at midnight)
  void resetDailyCounters() {
    _interstitialCount = 0;
    debugPrint('🎯 Ad counters reset for new day');
  }

  // ============================================
  // AD NETWORK INTEGRATION
  // ============================================

  /// Load banner ad for dashboard
  Future<void> _loadBannerAd() async {
    _bannerAd?.dispose();
    
    _bannerAd = BannerAd(
      adUnitId: _testBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => debugPrint('✓ Banner ad loaded'),
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner ad failed: $error');
          ad.dispose();
        },
      ),
    );
    
    await _bannerAd?.load();
  }
  
  /// Get loaded banner ad
  BannerAd? get bannerAd => _bannerAd;

  /// Load native ad for list placement
  Future<NativeAd?> loadNativeAd(String placement) async {
    if (_nativeAds.containsKey(placement)) {
      return _nativeAds[placement];
    }
    
    final nativeAd = NativeAd(
      adUnitId: _testNativeAdUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) => debugPrint('✓ Native ad loaded: $placement'),
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Native ad failed: $error');
          ad.dispose();
        },
      ),
    );
    
    await nativeAd.load();
    _nativeAds[placement] = nativeAd;
    return nativeAd;
  }

  /// Preload interstitial ads
  Future<void> _preloadInterstitial() async {
    await InterstitialAd.load(
      adUnitId: _testInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          debugPrint('✓ Interstitial ad preloaded');
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _preloadInterstitial(); // Preload next
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Interstitial failed to show: $error');
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
  
  /// Preload rewarded ads
  Future<void> _preloadRewarded() async {
    await RewardedAd.load(
      adUnitId: _testRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          debugPrint('✓ Rewarded ad preloaded');
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _preloadRewarded(); // Preload next
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Rewarded ad failed to show: $error');
              ad.dispose();
              _preloadRewarded();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Rewarded ad failed to load: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Dispose ad resources
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    
    for (final ad in _nativeAds.values) {
      ad.dispose();
    }
    _nativeAds.clear();
    
    debugPrint('🎯 SimpleAdService disposed');
  }
}

/// Ad placement identifiers for analytics
class AdPlacement {
  static const String dashboardBanner = 'dashboard_banner';
  static const String medicationNative = 'medication_native';
  static const String financeNative = 'finance_native';
  static const String notesNative = 'notes_native';
  static const String periodNative = 'period_native';
  static const String reminderInterstitial = 'reminder_interstitial';
  static const String focusInterstitial = 'focus_interstitial';
  static const String waterInterstitial = 'water_interstitial';
  static const String rewardedVideo = 'rewarded_video';
}
