import 'package:flutter/material.dart';
import '../core/design/app_design.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/services/simple_ad_service.dart';

/// Smart Banner Ad - Persistent at bottom of dashboard
class SmartDashboardBanner extends StatelessWidget {
  const SmartDashboardBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final adService = SimpleAdService();

    // Rebuild when the ad's load state CHANGES, not when something unrelated
    // happens to rebuild this subtree.
    //
    // This widget reads `bannerLoaded` directly and nothing notified on it, so
    // it stayed a zero-height SizedBox until an unrelated rebuild ran — and on
    // this app that is a tab switch. ~84pt of content therefore appeared while
    // the user was navigating, shoving the dashboard down under their thumb.
    return ValueListenableBuilder<bool>(
      valueListenable: adService.bannerReady,
      builder: (context, ready, _) {
        final bannerAd = adService.bannerAd;

        // Only insert the AdWidget once the ad has actually loaded — inserting
        // it before load() completes throws and paints a red error box.
        if (!adService.shouldShowDashboardBanner || bannerAd == null || !ready) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          height: 60,
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          alignment: Alignment.center,
          child: AdWidget(ad: bannerAd),
        );
      },
    );
  }
}

// NOTE: native-in-list "SmartNativeListAd" was removed — ads must never sit
// beside health data (period/vitals/sleep/medication lists). Revenue ads are
// limited to the home-overview banner + interstitials on neutral events.

/// Ad-Free Message (shows where ads would be)
class AdFreeMessage extends StatelessWidget {
  const AdFreeMessage({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // `success.container` rather than a light-only green at 10% opacity:
        // the container token is defined per theme, so the wash no longer
        // resolves to a light tint on a dark surface.
        color: ext.success.container,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ext.mark(ext.success).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Symbols.check_circle_rounded,
              color: ext.mark(ext.success), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '100% Free Forever • Supported by Ads',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ext.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
