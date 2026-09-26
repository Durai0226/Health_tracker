import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env_config.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/constants/app_strings.dart';

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
/// `readTypesFor` / `vitalsWriteTypes` / `hydrationWriteTypes`. They are written out in plain language
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
              leading: AppHeader.backButton(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                    AppSpacing.md, AppSpacing.gutter, AppSpacing.xxl),
                children: [
                  Text(
                    '${AppStrings.productName} reads a small amount of health data so your '
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
                      AppListTile(
                        icon: Symbols.water_drop_rounded,
                        iconColor: ext.mark(ext.water),
                        title: 'Water logged in other apps',
                        subtitle: 'So your daily total counts drinks you '
                            'recorded elsewhere',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  SettingsSection(
                    title: 'What we write back',
                    footer: 'All off by default. Turn them on in Vitals '
                        'settings and Hydration settings if you want other '
                        'health apps to see this.',
                    children: [
                      AppListTile(
                        icon: Symbols.monitor_heart_rounded,
                        iconColor: ext.mark(ext.medicine),
                        title: 'Blood pressure, blood sugar and weight',
                        subtitle: 'Only readings you logged here yourself',
                      ),
                      AppListTile(
                        icon: Symbols.water_drop_rounded,
                        iconColor: ext.mark(ext.water),
                        title: 'Drinks you log',
                        subtitle: 'The amount you drank and when — not the '
                            'drink type, and not our hydration adjustment',
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
                        icon: Symbols.thermostat_rounded,
                        iconColor: ext.mark(ext.water),
                        title: 'Weather, only if you turn it on',
                        subtitle: 'If you switch on hot-weather goals, the town '
                            'name you type is sent to Open-Meteo to look up the '
                            'temperature. No location permission is used and no '
                            'health data is sent.',
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
                        '${AppStrings.productName}.',
                    children: [
                      AppListTile(
                        icon: Symbols.tune_rounded,
                        iconColor: ext.mark(ext.brand),
                        title: 'Change or revoke access any time',
                        subtitle: 'Health Connect → App permissions → '
                            '${AppStrings.productName} (or Apple Health → Sharing on iPhone)',
                      ),
                      AppListTile(
                        icon: Symbols.delete_rounded,
                        iconColor: ext.mark(ext.brand),
                        title: 'Delete everything',
                        // Both rows, because they do different things. This
                        // named a single 'Settings → Clear all data' — a row
                        // that does not exist — and credited it with clearing
                        // the account too, which the local wipe has never
                        // done. The row that does is 'Delete account'.
                        subtitle: 'Settings → Delete all data erases it from '
                            'this device; Delete account also erases your '
                            'cloud copies',
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
                    '${AppStrings.productName} is a general wellness and reminder tool — not '
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
