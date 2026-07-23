import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';

/// Plain-language "AI & your data" policy — states, in the user's words, what
/// the assistant stores, that it stays on this device, that it's encrypted, that
/// it's not a diagnosis, and exactly how to delete it. Reachable from the
/// Memories screen and the Settings → AI section (privacy shouldn't be buried).
class AiPrivacyScreen extends StatelessWidget {
  const AiPrivacyScreen({super.key});

  static const _points = <(IconData, String, String)>[
    (
      Symbols.phonelink_lock_rounded,
      'It runs on your device',
      'The assistant answers from your own logs and a built-in wellness knowledge base — all on this phone. Your questions and health data are not sent to any server.'
    ),
    (
      Symbols.psychology_rounded,
      'It remembers only what you tell it',
      'Memories are created only when you explicitly say so (“remember …”, “my goal is …”). Nothing is pulled silently from your health data, and you can view or delete every note in Memory.'
    ),
    (
      Symbols.lock_rounded,
      'Stored privately on your device',
      'Your logs and memories live in the app\'s private storage, which your phone encrypts at rest while the device is locked (iOS Data Protection / Android encryption). No other app can read them.'
    ),
    (
      Symbols.cloud_off_rounded,
      'Left out of cloud sync & backups',
      'Your memories and the knowledge base are deliberately kept off cloud sync and backups by default, so they don\'t leave the device unless you choose to.'
    ),
    (
      Symbols.menu_book_rounded,
      'Answers are grounded and cited',
      'Answers come from your own data or the curated knowledge base, with a Source you can tap to read. If it doesn\'t have a good answer, it says so instead of guessing.'
    ),
    (
      Symbols.health_and_safety_rounded,
      'Information, not a diagnosis',
      'The assistant shares general wellness information and patterns from your data. It is not medical advice, diagnosis, or treatment — always confirm with a qualified clinician or pharmacist. In an emergency, contact your local emergency services.'
    ),
    (
      Symbols.delete_rounded,
      'You can delete everything',
      'Clear individual notes or all of them in Memory. “Delete all data” in Settings erases your memories along with the rest of your data, and uninstalling the app removes everything.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'AI & your data',
            accent: accent,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: accent,
              onPressed: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
            ),
            bottom: Container(height: 1, color: ext.outline),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                  AppSpacing.lg, AppSpacing.gutter, AppSpacing.huge),
              children: [
                Text('How your assistant handles your data',
                    style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
                const SizedBox(height: AppSpacing.xs),
                Text('Private by design — here\'s exactly what happens.',
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
                const SizedBox(height: AppSpacing.lg),
                for (final p in _points) ...[
                  _point(ext, tt, p.$1, p.$2, p.$3),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.sm),
                const SafetyDisclaimerBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _point(AppColorsExt ext, TextTheme tt, IconData icon, String title,
      String body) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: ext.surfaceVariant, borderRadius: AppRadius.brMd),
            child: Icon(icon, size: 19, color: ext.mark(ext.brand)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(body,
                    style: tt.bodyMedium
                        ?.copyWith(color: ext.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
