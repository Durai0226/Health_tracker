
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';

class BannerAdPlaceholder extends StatelessWidget {
  const BannerAdPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if ads are disabled
    final settings = StorageService.getUserSettings();
    if (settings.isAdsDisabled) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ADVERTISEMENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upgrade to Premium to Remove Ads',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 2,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: const Text(
                'Ad',
                style: TextStyle(fontSize: 8, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
