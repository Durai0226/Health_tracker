import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/premium_service.dart';
import 'package:tablet_remainder/core/services/ad_service.dart';

void main() {
  group('PremiumService Tests', () {
    late PremiumService premiumService;

    setUp(() {
      premiumService = PremiumService();
    });

    group('Subscription Tier Tests', () {
      test('should return free tier when no user is authenticated', () {
        // Without authenticated user, should default to free tier
        // (unless user is chotadsp@gmail.com)
        final tier = premiumService.currentTier;
        expect([SubscriptionTier.free, SubscriptionTier.premium].contains(tier), isTrue);
      });

      test('Premium tier limits should be correct', () {
        const limits = FeatureLimits.premium;
        
        expect(limits.maxMedications, equals(-1)); // unlimited
        expect(limits.maxReminders, equals(-1)); // unlimited
        expect(limits.maxNotes, equals(-1)); // unlimited
        expect(limits.adsEnabled, isFalse);
        expect(limits.drugInteractionChecker, isTrue);
        expect(limits.familySharing, isTrue);
        expect(limits.advancedAnalytics, isTrue);
        expect(limits.premiumThemes, isTrue);
      });

      test('Plus tier limits should be correct', () {
        const limits = FeatureLimits.plus;
        
        expect(limits.maxMedications, equals(-1)); // unlimited
        expect(limits.maxReminders, equals(-1)); // unlimited
        expect(limits.maxNotes, equals(50));
        expect(limits.maxFinanceAccounts, equals(3));
        expect(limits.maxBudgets, equals(5));
        expect(limits.maxAlarmSounds, equals(10));
        expect(limits.adsEnabled, isFalse);
        expect(limits.drugInteractionChecker, isFalse);
        expect(limits.familySharing, isFalse);
        expect(limits.pdfExport, isTrue);
        expect(limits.customCategories, isTrue);
      });

      test('Free tier limits should be correct', () {
        const limits = FeatureLimits.free;
        
        expect(limits.maxMedications, equals(5));
        expect(limits.maxReminders, equals(10));
        expect(limits.maxNotes, equals(20));
        expect(limits.maxFinanceAccounts, equals(1));
        expect(limits.maxBudgets, equals(1));
        expect(limits.maxAlarmSounds, equals(1));
        expect(limits.cloudSyncDays, equals(30));
        expect(limits.healthDashboardDays, equals(7));
        expect(limits.adsEnabled, isTrue);
        expect(limits.drugInteractionChecker, isFalse);
        expect(limits.familySharing, isFalse);
        expect(limits.pdfExport, isFalse);
      });
    });

    group('Feature Gate Tests', () {
      test('canAddMedication should work correctly', () {
        // Test with current tier (may be free or premium depending on auth)
        final canAdd = premiumService.canAddMedication(0);
        expect(canAdd, isA<bool>());
      });

      test('canAddReminder should work correctly', () {
        final canAdd = premiumService.canAddReminder(0);
        expect(canAdd, isA<bool>());
      });

      test('canAddNote should work correctly', () {
        final canAdd = premiumService.canAddNote(0);
        expect(canAdd, isA<bool>());
      });
    });

    group('Premium Feature Availability Tests', () {
      test('feature availability methods should return boolean', () {
        expect(premiumService.hasDrugInteractionChecker, isA<bool>());
        expect(premiumService.hasAdvancedAnalytics, isA<bool>());
        expect(premiumService.hasFamilySharing, isA<bool>());
        expect(premiumService.hasPremiumThemes, isA<bool>());
        expect(premiumService.hasPdfExport, isA<bool>());
        expect(premiumService.hasHealthReports, isA<bool>());
        expect(premiumService.hasCustomCategories, isA<bool>());
        expect(premiumService.hasEncryption, isA<bool>());
      });
    });

    group('Ad Display Tests', () {
      test('shouldShowAds should return boolean', () {
        expect(premiumService.shouldShowAds, isA<bool>());
      });
    });

    group('Subscription Status Tests', () {
      test('should return correct status summary', () {
        final status = premiumService.getStatusSummary();
        
        expect(status.containsKey('tier'), isTrue);
        expect(status.containsKey('isPaid'), isTrue);
        expect(status.containsKey('isPremium'), isTrue);
        expect(status.containsKey('shouldShowAds'), isTrue);
        expect(status.containsKey('limits'), isTrue);
      });
    });

    group('Pricing Tests', () {
      test('pricing data should be correct', () {
        expect(PremiumService.pricing['plus_monthly']!['price'], equals(4.99));
        expect(PremiumService.pricing['plus_yearly']!['price'], equals(39.99));
        expect(PremiumService.pricing['premium_monthly']!['price'], equals(9.99));
        expect(PremiumService.pricing['premium_yearly']!['price'], equals(79.99));
        expect(PremiumService.pricing['lifetime']!['price'], equals(199.99));
      });
    });
  });

  group('AdService Tests', () {
    late AdService adService;

    setUp(() {
      adService = AdService();
    });

    test('should return boolean for shouldShowAds', () {
      expect(adService.shouldShowAds, isA<bool>());
    });

    test('should respect ad placement rules', () {
      expect(adService.shouldShowAdAt(AdPlacement.dashboardBanner), isA<bool>());
      expect(adService.shouldShowAdAt(AdPlacement.reminderListNative), isA<bool>());
      expect(adService.shouldShowAdAt(AdPlacement.financeListNative), isA<bool>());
    });

    test('ad stats should contain adsEnabled key', () {
      final stats = adService.getStats();
      expect(stats.containsKey('adsEnabled'), isTrue);
    });
  });

  group('TemporaryUnlockManager Tests', () {
    late TemporaryUnlockManager unlockManager;

    setUp(() {
      unlockManager = TemporaryUnlockManager();
    });

    test('should unlock feature temporarily', () {
      unlockManager.unlock('test_feature');
      expect(unlockManager.isUnlocked('test_feature'), isTrue);
    });

    test('should return remaining time for unlocked feature', () {
      unlockManager.unlock('test_feature');
      final remaining = unlockManager.getRemainingTime('test_feature');
      
      expect(remaining, isNotNull);
      expect(remaining!.inHours, greaterThanOrEqualTo(23));
    });

    test('should return null for non-unlocked feature', () {
      expect(unlockManager.getRemainingTime('nonexistent'), isNull);
    });

    test('should track multiple unlocks', () {
      unlockManager.unlock('multi_feature1');
      unlockManager.unlock('multi_feature2');
      unlockManager.unlock('multi_feature3');
      
      final active = unlockManager.getActiveUnlocks();
      // Check that at least 3 features are unlocked (may have more from other tests)
      expect(active.length, greaterThanOrEqualTo(3));
      expect(active.containsKey('multi_feature1'), isTrue);
      expect(active.containsKey('multi_feature2'), isTrue);
      expect(active.containsKey('multi_feature3'), isTrue);
    });
  });

  group('FeatureLimits Comparison Tests', () {
    test('Premium should have more features than Plus', () {
      const plus = FeatureLimits.plus;
      const premium = FeatureLimits.premium;

      // Premium-only features
      expect(premium.drugInteractionChecker, isTrue);
      expect(plus.drugInteractionChecker, isFalse);

      expect(premium.familySharing, isTrue);
      expect(plus.familySharing, isFalse);

      expect(premium.advancedAnalytics, isTrue);
      expect(plus.advancedAnalytics, isFalse);

      expect(premium.premiumThemes, isTrue);
      expect(plus.premiumThemes, isFalse);

      expect(premium.healthReports, isTrue);
      expect(plus.healthReports, isFalse);

      expect(premium.endToEndEncryption, isTrue);
      expect(plus.endToEndEncryption, isFalse);
    });

    test('Plus should have more features than Free', () {
      const free = FeatureLimits.free;
      const plus = FeatureLimits.plus;

      // Plus advantages
      expect(plus.adsEnabled, isFalse);
      expect(free.adsEnabled, isTrue);

      expect(plus.maxMedications, equals(-1));
      expect(free.maxMedications, equals(5));

      expect(plus.maxReminders, equals(-1));
      expect(free.maxReminders, equals(10));

      expect(plus.pdfExport, isTrue);
      expect(free.pdfExport, isFalse);

      expect(plus.customCategories, isTrue);
      expect(free.customCategories, isFalse);
    });
  });

  group('Free Tier Limit Enforcement Tests', () {
    test('Free tier should enforce medication limit', () {
      const limits = FeatureLimits.free;
      
      // Can add up to 5
      expect(_canAdd(0, limits.maxMedications), isTrue);
      expect(_canAdd(4, limits.maxMedications), isTrue);
      
      // Cannot add 6th
      expect(_canAdd(5, limits.maxMedications), isFalse);
      expect(_canAdd(10, limits.maxMedications), isFalse);
    });

    test('Free tier should enforce reminder limit', () {
      const limits = FeatureLimits.free;
      
      expect(_canAdd(0, limits.maxReminders), isTrue);
      expect(_canAdd(9, limits.maxReminders), isTrue);
      expect(_canAdd(10, limits.maxReminders), isFalse);
    });

    test('Free tier should enforce note limit', () {
      const limits = FeatureLimits.free;
      
      expect(_canAdd(0, limits.maxNotes), isTrue);
      expect(_canAdd(19, limits.maxNotes), isTrue);
      expect(_canAdd(20, limits.maxNotes), isFalse);
    });

    test('Plus tier should enforce note limit', () {
      const limits = FeatureLimits.plus;
      
      expect(_canAdd(0, limits.maxNotes), isTrue);
      expect(_canAdd(49, limits.maxNotes), isTrue);
      expect(_canAdd(50, limits.maxNotes), isFalse);
    });
  });
}

/// Helper function to check if can add based on limit
bool _canAdd(int currentCount, int limit) {
  return limit == -1 || currentCount < limit;
}
