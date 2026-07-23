import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'clean_storage_service.dart';

/// Asks for a store rating ONCE, and only after a real "win" (a medication
/// adherence streak) — the retention→ratings→ASO loop the BA flagged as the only
/// affordable growth channel. Never nags: it records that it asked regardless of
/// the user's choice, so it fires at most once per install.
class RatingPromptService {
  const RatingPromptService._();

  static const String _shownKey = 'rating_prompt_shown';
  static const String _androidId = 'com.dlyminder.app';
  // TODO: replace with the real App Store numeric id once published.
  static const String _iosId = '0000000000';

  static bool get _alreadyAsked =>
      CleanStorageService.getAppPreference(_shownKey, false) == true;

  /// Prompt if the user just hit a streak milestone and hasn't been asked before.
  static Future<void> maybePrompt(
    BuildContext context, {
    required int streak,
    int threshold = 7,
  }) async {
    if (_alreadyAsked || streak < threshold) return;
    // Record immediately so we never ask twice, whatever they choose.
    await CleanStorageService.setAppPreference(_shownKey, true);
    if (!context.mounted) return;

    final rate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enjoying DailyMinder?'),
        content: Text(
            "You're on a $streak-day streak — nicely done! A quick rating "
            'really helps others find a private, free reminder app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rate')),
        ],
      ),
    );
    if (rate == true) await _openStore();
  }

  static Future<void> _openStore() async {
    final url = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/app/id$_iosId')
        : Uri.parse(
            'https://play.google.com/store/apps/details?id=$_androidId');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Non-fatal — the prompt has already done its job of asking.
    }
  }
}
