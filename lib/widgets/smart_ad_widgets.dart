import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
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

    // Only insert the AdWidget once the ad has actually loaded — inserting it
    // before load() completes throws and paints a red error box (the glitch
    // seen when switching to a tab that hosts the banner).
    if (!adService.shouldShowDashboardBanner ||
        bannerAd == null ||
        !adService.bannerLoaded) {
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

// NOTE: native-in-list "SmartNativeListAd" was removed — ads must never sit
// beside health data (period/vitals/sleep/medication lists). Revenue ads are
// limited to the home-overview banner + interstitials on neutral events.

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
    this.icon = Symbols.play_circle_rounded,
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
          side: const BorderSide(color: AppColors.warning),
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
            AppColors.success.withValues(alpha: 0.1),
            AppColors.success.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Symbols.check_circle_rounded, color: AppColors.success, size: 20),
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
