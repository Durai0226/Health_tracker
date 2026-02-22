import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/constants/app_colors.dart';
import '../core/services/simple_ad_service.dart';

/// Smart Banner Ad - Persistent at bottom of dashboard
class SmartDashboardBanner extends StatelessWidget {
  const SmartDashboardBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final adService = SimpleAdService();
    final bannerAd = adService.bannerAd;
    
    if (!adService.shouldShowDashboardBanner || bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      alignment: Alignment.center,
      child: AdWidget(ad: bannerAd),
    );
  }
}

/// Native Ad for Lists - Blends with list items
class SmartNativeListAd extends StatelessWidget {
  final String placement;
  final int index;

  const SmartNativeListAd({
    super.key,
    required this.placement,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final adService = SimpleAdService();
    
    // Check if ad should show at this index
    bool shouldShow = false;
    switch (placement) {
      case AdPlacement.medicationNative:
        shouldShow = adService.shouldShowMedicationNativeAd(index);
        break;
      case AdPlacement.financeNative:
        shouldShow = adService.shouldShowFinanceNativeAd(index);
        break;
      case AdPlacement.notesNative:
        shouldShow = adService.shouldShowNotesNativeAd(index);
        break;
    }

    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    final isDark = AppColors.isDark(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.star_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getAdTitle(placement),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getAdDescription(placement),
                      style: TextStyle(
                        color: isDark ? Colors.white60 : AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                // TODO: Handle ad click
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Learn More'),
            ),
          ),
        ],
      ),
    );
  }

  String _getAdTitle(String placement) {
    switch (placement) {
      case AdPlacement.medicationNative:
        return 'Track Your Health Better';
      case AdPlacement.financeNative:
        return 'Smart Financial Planning';
      case AdPlacement.notesNative:
        return 'Organize Your Thoughts';
      default:
        return 'Discover Something New';
    }
  }

  String _getAdDescription(String placement) {
    switch (placement) {
      case AdPlacement.medicationNative:
        return 'Get personalized health insights and reminders';
      case AdPlacement.financeNative:
        return 'Take control of your finances today';
      case AdPlacement.notesNative:
        return 'Powerful note-taking for productivity';
      default:
        return 'Tap to learn more about this offer';
    }
  }
}

/// Interstitial Ad Placeholder (shows before actual ad loads)
class InterstitialAdPlaceholder extends StatelessWidget {
  final String placement;
  final VoidCallback onAdClosed;

  const InterstitialAdPlaceholder({
    super.key,
    required this.placement,
    required this.onAdClosed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              'Loading ad...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: onAdClosed,
              child: const Text(
                'Skip',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rewarded Video Ad Button
class RewardedAdButton extends StatelessWidget {
  final String rewardDescription;
  final VoidCallback onRewarded;
  final IconData icon;

  const RewardedAdButton({
    super.key,
    required this.rewardDescription,
    required this.onRewarded,
    this.icon = Icons.play_circle_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: OutlinedButton.icon(
        onPressed: () async {
          final adService = SimpleAdService();
          final success = await adService.showRewardedAd(
            featureName: rewardDescription,
            onRewarded: (feature) {
              onRewarded();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✓ $rewardDescription'),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          );

          if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ad not available. Try again later.'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        },
        icon: Icon(icon),
        label: Text('Watch Ad: $rewardDescription'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.warning,
          side: BorderSide(color: AppColors.warning),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Ad-Free Message (shows where ads would be)
class AdFreeMessage extends StatelessWidget {
  const AdFreeMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withOpacity(0.1),
            AppColors.success.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '100% Free Forever • Supported by Ads',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
