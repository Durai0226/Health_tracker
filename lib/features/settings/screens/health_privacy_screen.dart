import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env_config.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// The app's canonical health-data disclosure.
///
/// This is the destination for BOTH Health Connect deep links declared in
/// `AndroidManifest.xml` — `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE`
/// (the "privacy policy" affordance on the consent sheet) and Android 14+'s
/// `ACTION_VIEW_PERMISSION_USAGE`. Until now both filters pointed at
/// MainActivity, which did not handle intents at all, so they simply brought
/// the app forward on whatever route it happened to be on. Google reviews that
/// flow for any app declaring health permissions, so this screen is a release
/// prerequisite, not a nicety. See `MainActivity.captureHealthIntent` and
/// [HealthRationaleChannel].
///
/// It is also reachable from Settings → Privacy, because a disclosure the user
/// can only reach by leaving the app is not much of a disclosure.
///
/// ## Keeping this honest
///
/// The lists below must match what `HealthDataService` actually requests —
/// `readTypesFor` / `vitalsWriteTypes`. They are written out in plain language
/// rather than generated from those constants, because a reviewer (and a user)
/// needs "how long you slept", not `SLEEP_REM`. **If you add a data type,
/// change this screen in the same commit.** Claiming less than you read is the
/// specific thing that fails review.
class HealthPrivacyScreen extends StatelessWidget {
  const HealthPrivacyScreen({super.key});

  Future<void> _openPolicy() async {
    final uri = Uri.tryParse(EnvConfig.privacyPolicyUrl);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Non-fatal: the disclosure itself is on this screen, not behind the link.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return AccentScope(
      feature: FeatureAccent.brand,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Health data & privacy',
              icon: Symbols.health_and_safety_rounded,
              accent: ext.brand,
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                accent: ext.brand,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                    AppSpacing.md, AppSpacing.gutter, AppSpacing.xxl),
                children: [
                  Text(
                    'DailyMinder reads a small amount of health data so your '
                    'trackers reflect what your phone and any connected watch '
                    'or band already recorded — instead of asking you to type '
                    'it in twice.',
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  SettingsSection(
                    title: 'What we read',
                    footer: 'Read only when you turn the connection on, and '
                        'only for the days a tracker actually shows.',
                    children: [
                      AppListTile(
                        icon: Symbols.directions_walk_rounded,
                        iconColor: ext.mark(ext.steps),
                        title: 'Steps, distance and active calories',
                        subtitle: 'Fills in the Steps tracker and its trends',
                      ),
                      AppListTile(
                        icon: Symbols.bedtime_rounded,
                        iconColor: ext.mark(ext.sleep),
                        title: 'Sleep, including its stages',
                        subtitle: 'Fills in the Sleep tracker and its trends',
                      ),
                      AppListTile(
                        icon: Symbols.monitor_weight_rounded,
                        iconColor: ext.mark(ext.medicine),
                        title: 'Weight',
                        subtitle: 'Only when you tap "Import" on the Weight '
                            'screen — never in the background',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  SettingsSection(
                    title: 'What we write back',
                    footer: 'Off by default. Turn it on in Vitals settings if '
                        'you want other health apps to see these readings.',
                    children: [
                      AppListTile(
                        icon: Symbols.monitor_heart_rounded,
                        iconColor: ext.mark(ext.medicine),
                        title: 'Blood pressure, blood sugar and weight',
                        subtitle: 'Only readings you logged here yourself',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  SettingsSection(
                    title: 'Where it goes',
                    children: [
                      AppListTile(
                        icon: Symbols.phone_iphone_rounded,
                        iconColor: ext.mark(ext.brand),
                        title: 'It stays on this device',
                        subtitle: 'Stored in the app\'s own private database',
                      ),
                      AppListTile(
                        icon: Symbols.cloud_off_rounded,
                        iconColor: ext.mark(ext.brand),
                        title: 'No cloud backup unless you ask',
                        subtitle: 'Cloud sync is off until you sign in and turn '
                            'it on. Then it goes only to your own account.',
                      ),
                      AppListTile(
                        icon: Symbols.sell_rounded,
                        iconColor: ext.mark(ext.brand),
                        title: 'Never sold, never used for ads',
                        subtitle: 'Health data is not shared with advertisers '
                            'or any third party',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  SettingsSection(
                    title: 'You stay in control',
                    footer: 'Revoking access stops new data arriving. Anything '
                        'already saved here stays until you delete it in '
                        'DailyMinder.',
                    children: [
                      AppListTile(
                        icon: Symbols.tune_rounded,
                        iconColor: ext.mark(ext.brand),
                        title: 'Change or revoke access any time',
                        subtitle: 'Health Connect → App permissions → '
                            'DailyMinder (or Apple Health → Sharing on iPhone)',
                      ),
                      AppListTile(
                        icon: Symbols.delete_rounded,
                        iconColor: ext.mark(ext.brand),
                        title: 'Delete everything',
                        subtitle: 'Settings → Clear all data removes it from '
                            'this device and your account',
                      ),
                    ],
                  ),

                  if (EnvConfig.hasPrivacyPolicy) ...[
                    const SizedBox(height: AppSpacing.lg),
                    SettingsSection(
                      children: [
                        AppListTile(
                          icon: Symbols.open_in_new_rounded,
                          iconColor: ext.mark(ext.brand),
                          title: 'Full privacy policy',
                          subtitle: 'Opens in your browser',
                          onTap: _openPolicy,
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'DailyMinder is a general wellness and reminder tool — not '
                    'a medical device, and not a source of diagnosis or '
                    'treatment. Always confirm health decisions with a '
                    'qualified clinician or pharmacist.',
                    style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
