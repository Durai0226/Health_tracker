import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/simple_ad_service.dart';

void main() {
  group('SimpleAdService Tests', () {
    late SimpleAdService adService;

    setUp(() {
      adService = SimpleAdService();
    });

    group('Initialization Tests', () {
      test('should initialize successfully', () async {
        await adService.init();
        expect(adService, isNotNull);
      });
    });

    group('Dashboard Banner Tests', () {
      test('should always show dashboard banner', () {
        expect(adService.shouldShowDashboardBanner, isTrue);
      });
    });

    group('Medication Native Ad Tests', () {
      test('should not show ad at index 0', () {
        expect(adService.shouldShowMedicationNativeAd(0), isFalse);
      });

      test('should show ad at index 5', () {
        expect(adService.shouldShowMedicationNativeAd(5), isTrue);
      });

      test('should show ad at index 10', () {
        expect(adService.shouldShowMedicationNativeAd(10), isTrue);
      });

      test('should not show ad at index 3', () {
        expect(adService.shouldShowMedicationNativeAd(3), isFalse);
      });

      test('should show ad at index 15', () {
        expect(adService.shouldShowMedicationNativeAd(15), isTrue);
      });
    });

    group('Finance Native Ad Tests', () {
      test('should not show ad at index 0', () {
        expect(adService.shouldShowFinanceNativeAd(0), isFalse);
      });

      test('should show ad at index 3', () {
        expect(adService.shouldShowFinanceNativeAd(3), isTrue);
      });

      test('should show ad at index 6', () {
        expect(adService.shouldShowFinanceNativeAd(6), isTrue);
      });

      test('should not show ad at index 2', () {
        expect(adService.shouldShowFinanceNativeAd(2), isFalse);
      });
    });

    group('Notes Native Ad Tests', () {
      test('should not show ad at index 0', () {
        expect(adService.shouldShowNotesNativeAd(0), isFalse);
      });

      test('should show ad at index 10', () {
        expect(adService.shouldShowNotesNativeAd(10), isTrue);
      });

      test('should show ad at index 20', () {
        expect(adService.shouldShowNotesNativeAd(20), isTrue);
      });

      test('should not show ad at index 5', () {
        expect(adService.shouldShowNotesNativeAd(5), isFalse);
      });
    });

    group('Period Native Ad Tests', () {
      test('should always show period native ad', () {
        expect(adService.shouldShowPeriodNativeAd, isTrue);
      });
    });

    group('Interstitial Ad Tests', () {
      test('should track reminder dismissals', () async {
        // First 4 dismissals should not trigger ad
        for (int i = 0; i < 4; i++) {
          final shown = await adService.onReminderDismissed();
          expect(shown, isFalse);
        }
        
        // 5th dismissal should trigger ad
        final shown = await adService.onReminderDismissed();
        expect(shown, isTrue);
      });

      test('should show interstitial after focus session', () async {
        final shown = await adService.onFocusSessionComplete();
        expect(shown, isA<bool>());
      });

      test('should show interstitial after water goal', () async {
        final shown = await adService.onWaterGoalReached();
        expect(shown, isA<bool>());
      });
    });

    group('Rewarded Ad Tests', () {
      test('should show rewarded ad and call callback', () async {
        bool callbackCalled = false;
        String? featureRewarded;

        final shown = await adService.showRewardedAd(
          featureName: 'test_feature',
          onRewarded: (feature) {
            callbackCalled = true;
            featureRewarded = feature;
          },
        );

        expect(shown, isTrue);
        expect(callbackCalled, isTrue);
        expect(featureRewarded, equals('test_feature'));
      });

      test('should offer rewarded for coins', () async {
        final shown = await adService.offerRewardedForCoins();
        expect(shown, isTrue);
      });
    });

    group('Ad Stats Tests', () {
      test('should return ad statistics', () {
        final stats = adService.getAdStats();

        expect(stats.containsKey('interstitials_shown_today'), isTrue);
        expect(stats.containsKey('last_interstitial'), isTrue);
        expect(stats.containsKey('reminder_dismissals'), isTrue);
        expect(stats.containsKey('can_show_interstitial'), isTrue);
      });

      test('should reset daily counters', () {
        adService.resetDailyCounters();
        final stats = adService.getAdStats();
        expect(stats['interstitials_shown_today'], equals(0));
      });
    });

    group('Frequency Capping Tests', () {
      test('should respect max interstitials per day', () async {
        // Reset counters first
        adService.resetDailyCounters();
        
        // Show 6 interstitials (max limit)
        for (int i = 0; i < 6; i++) {
          await adService.showInterstitialAd('test_$i');
        }
        
        // 7th should be blocked by frequency cap
        final stats = adService.getAdStats();
        expect(stats['can_show_interstitial'], isFalse);
      });
    });
  });

  group('AdPlacement Constants Tests', () {
    test('should have correct placement identifiers', () {
      expect(AdPlacement.dashboardBanner, equals('dashboard_banner'));
      expect(AdPlacement.medicationNative, equals('medication_native'));
      expect(AdPlacement.financeNative, equals('finance_native'));
      expect(AdPlacement.notesNative, equals('notes_native'));
      expect(AdPlacement.periodNative, equals('period_native'));
      expect(AdPlacement.reminderInterstitial, equals('reminder_interstitial'));
      expect(AdPlacement.focusInterstitial, equals('focus_interstitial'));
      expect(AdPlacement.waterInterstitial, equals('water_interstitial'));
      expect(AdPlacement.rewardedVideo, equals('rewarded_video'));
    });
  });

  group('Ad Revenue Estimation Tests', () {
    test('should calculate expected ad placements', () {
      // Based on strategy: 8 strategic placements
      const expectedPlacements = [
        'dashboard_banner',
        'medication_native',
        'finance_native',
        'notes_native',
        'period_native',
        'reminder_interstitial',
        'focus_interstitial',
        'water_interstitial',
      ];

      for (final placement in expectedPlacements) {
        expect(
          [
            AdPlacement.dashboardBanner,
            AdPlacement.medicationNative,
            AdPlacement.financeNative,
            AdPlacement.notesNative,
            AdPlacement.periodNative,
            AdPlacement.reminderInterstitial,
            AdPlacement.focusInterstitial,
            AdPlacement.waterInterstitial,
          ].contains(placement),
          isTrue,
          reason: 'Missing placement: $placement',
        );
      }
    });
  });
}
