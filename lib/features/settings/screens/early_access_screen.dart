import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/services/feature_flag_service.dart';
import '../../../core/widgets/app/app_widgets.dart';

class EarlyAccessScreen extends StatefulWidget {
  const EarlyAccessScreen({super.key});

  @override
  State<EarlyAccessScreen> createState() => _EarlyAccessScreenState();
}

class _EarlyAccessScreenState extends State<EarlyAccessScreen> {
  final _featureService = FeatureFlagService();

  @override
  Widget build(BuildContext context) {
    // The last Material `AppBar` on a flat screen. It was also the only header
    // whose title style was a raw `TextStyle` rather than a theme role, so it
    // rendered at the default 20pt medium against `headlineSmall` 18/w600
    // everywhere else, and its `AppColors.*` calls are the legacy shim.
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeader(
            title: 'Early access',
            leading: AppHeader.backButton(context),
          ),
          Expanded(
            child: ValueListenableBuilder<bool>(
        valueListenable: _featureService.notifier,
        builder: (context, _, __) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md,
                AppSpacing.gutter, AppSpacing.xl),
            children: [
              // The hand-rolled "Heads up!" card and the hand-rolled
              // "EXPERIMENTAL FEATURES" caption both went: the section supplies
              // a caption and a footer, and all three said the same thing in
              // three different type treatments — a 12pt bold letter-spaced
              // caption, a bold orange heading, and a 13pt body line.
              SettingsSection(
                title: 'Experimental',
                footer: 'These can change, break or disappear at any time.',
                children: [
                  _flag(
                    key: FeatureFlagService.keyAdvancedRepeat,
                    icon: Symbols.update_rounded,
                    title: 'Advanced repeat options',
                    subtitle: 'Complex recurrence rules',
                  ),
                  _flag(
                    key: FeatureFlagService.keyPremiumThemes,
                    icon: Symbols.palette_rounded,
                    title: 'Premium themes',
                    subtitle: 'Extra colour themes',
                  ),
                  _flag(
                    key: FeatureFlagService.keyBetaFeatures,
                    icon: Symbols.science_rounded,
                    title: 'Beta features',
                    subtitle: 'May be unstable',
                  ),
                ],
              ),
            ],
          );
        },
            ),
          ),
        ],
      ),
    );
  }



  /// One feature flag, on the shared row.
  ///
  /// This was a hand-rolled card per flag: its own `Container` with a 20pt
  /// radius and a hand-written shadow, a 10pt-padded 24pt glyph in a
  /// hardcoded `Colors.blue` / `.purple` / `.orange` wash, `fontSize: 16` and
  /// `fontSize: 13` literals, and three `AppColors.*` calls through the legacy
  /// shim. It also did not toggle on a row tap and announced its switch as a
  /// bare "switch, on".
  ///
  /// `SettingsTile` supplies all of that, and the per-flag colour goes on
  /// purpose — its doc calls the neutral chip "the fix for the per-row colour
  /// zoo", and three unrelated hues on three rows is that zoo.
  Widget _flag({
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
  }) =>
      SettingsTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        switchValue: _featureService.isEnabled(key),
        onSwitchChanged: (v) async {
          await _featureService.setEnabled(key, v);
          if (mounted) setState(() {});
        },
      );

}
