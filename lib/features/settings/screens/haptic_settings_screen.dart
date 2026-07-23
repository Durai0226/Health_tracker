import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// Haptic feedback settings — rebuilt on the Calm Clarity design system.
/// Flat [AppScaffold] + [AppHeader] (no colored bar), token-driven throughout,
/// grouped [SettingsSection] rows with one neutral icon treatment, brand teal
/// [AppSwitch] / [SegmentedToggle], and a [AppBottomSheet] pattern explorer.
/// Every glyph is a Material Symbol — no emoji, no per-row color zoo.
class HapticSettingsScreen extends StatefulWidget {
  const HapticSettingsScreen({super.key});

  @override
  State<HapticSettingsScreen> createState() => _HapticSettingsScreenState();
}

class _HapticSettingsScreenState extends State<HapticSettingsScreen> {
  final _hapticService = HapticService();

  /// The three selectable intensities (custom is never picked from the UI).
  static const List<HapticIntensity> _intensitySteps = [
    HapticIntensity.light,
    HapticIntensity.medium,
    HapticIntensity.heavy,
  ];

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AccentScope(
      feature: FeatureAccent.brand,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Haptic feedback',
              icon: Symbols.vibration_rounded,
              accent: ext.brand,
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                accent: ext.brand,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _hapticService,
                builder: (context, _) {
                  final ext = AppColorsExt.of(context);
                  final enabled = _hapticService.isEnabled;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.sm, AppSpacing.gutter, AppSpacing.xxl),
                    children: [
                      // Master toggle.
                      SettingsSection(
                        title: 'Feedback',
                        footer:
                            'Subtle vibrations for taps, reminders, and milestones.',
                        children: [
                          SettingsTile(
                            icon: Symbols.vibration_rounded,
                            title: 'Haptic Feedback',
                            switchValue: enabled,
                            onSwitchChanged: (v) => _hapticService.setEnabled(v),
                          ),
                        ],
                      ),

                      if (enabled) ...[
                        const SizedBox(height: AppSpacing.xl),

                        // Global intensity.
                        SettingsSection(
                          title: 'Intensity',
                          footer:
                              'Sets the strength of every vibration across the app.',
                          children: [_intensityRow(ext)],
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Per-feature haptics — neutral value rows.
                        SettingsSection(
                          title: 'Feature haptics',
                          footer:
                              'Tune the feel of each feature. Tap a row to adjust.',
                          children: [
                            _featureTile(
                              feature: HapticFeature.medication,
                              title: 'Medicine Taken',
                              icon: Symbols.medication_rounded,
                            ),
                            _featureTile(
                              feature: HapticFeature.medication,
                              title: 'Medicine Reminder',
                              icon: Symbols.alarm_rounded,
                            ),
                            _featureTile(
                              feature: HapticFeature.water,
                              title: 'Water Added',
                              icon: Symbols.water_drop_rounded,
                            ),
                            _featureTile(
                              feature: HapticFeature.water,
                              title: 'Water Goal',
                              icon: Symbols.trophy_rounded,
                            ),
                            _featureTile(
                              feature: HapticFeature.focus,
                              title: 'Focus Start',
                              icon: Symbols.self_improvement_rounded,
                            ),
                            _featureTile(
                              feature: HapticFeature.focus,
                              title: 'Focus Complete',
                              icon: Symbols.check_circle_rounded,
                            ),
                            _featureTile(
                              feature: HapticFeature.navigation,
                              title: 'Navigation',
                              icon: Symbols.touch_app_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Pattern explorer.
                        SettingsSection(
                          title: 'Patterns',
                          footer: 'Preview every built-in vibration pattern.',
                          children: [
                            SettingsTile(
                              icon: Symbols.graphic_eq_rounded,
                              title: 'Pattern explorer',
                              subtitle: 'Test all vibration patterns',
                              onTap: _showPatternExplorer,
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Full-width label-only intensity picker inside the group card.
  Widget _intensityRow(AppColorsExt ext) {
    final index = _intensitySteps
        .indexOf(_hapticService.globalIntensity)
        .clamp(0, _intensitySteps.length - 1);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SegmentedToggle(
        accent: ext.brand,
        index: index,
        items: const [
          SegmentItem(label: 'Light'),
          SegmentItem(label: 'Medium'),
          SegmentItem(label: 'Heavy'),
        ],
        onChanged: (i) {
          final intensity = _intensitySteps[i];
          _hapticService.setGlobalIntensity(intensity);
          _previewIntensity(intensity);
        },
      ),
    );
  }

  /// A feature row: neutral tile + title + current intensity (or "Off") + chevron.
  Widget _featureTile({
    required HapticFeature feature,
    required String title,
    required IconData icon,
  }) {
    final isEnabled = _hapticService.featureEnabled[feature] ?? true;
    final intensity =
        _hapticService.featureIntensity[feature] ?? HapticIntensity.medium;
    return SettingsTile(
      icon: icon,
      title: title,
      value: isEnabled ? _intensityLabel(intensity) : 'Off',
      onTap: () => _showFeatureSettings(feature, title),
    );
  }

  void _showFeatureSettings(HapticFeature feature, String title) {
    AppBottomSheet.show(
      context,
      title: title,
      icon: Symbols.vibration_rounded,
      accent: AppColorsExt.of(context).brand,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final ext = AppColorsExt.of(ctx);
            final tt = Theme.of(ctx).textTheme;
            final isEnabled = _hapticService.featureEnabled[feature] ?? true;
            final intensity =
                _hapticService.featureIntensity[feature] ?? HapticIntensity.medium;
            final idx = _intensitySteps
                .indexOf(intensity)
                .clamp(0, _intensitySteps.length - 1);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Enable for this feature.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: ext.surfaceVariant,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Enable for this feature',
                          style:
                              tt.titleLarge?.copyWith(color: ext.textPrimary),
                        ),
                      ),
                      AppSwitch(
                        value: isEnabled,
                        onChanged: (v) {
                          _hapticService.setFeatureEnabled(feature, v);
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                if (isEnabled) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Intensity',
                      style:
                          tt.labelLarge?.copyWith(color: ext.textSecondary)),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedToggle(
                    accent: ext.brand,
                    index: idx,
                    items: const [
                      SegmentItem(label: 'Light'),
                      SegmentItem(label: 'Medium'),
                      SegmentItem(label: 'Heavy'),
                    ],
                    onChanged: (i) {
                      final chosen = _intensitySteps[i];
                      _hapticService.setFeatureIntensity(feature, chosen);
                      _previewIntensity(chosen);
                      setSheetState(() {});
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  void _showPatternExplorer() {
    AppBottomSheet.show(
      context,
      title: 'Pattern explorer',
      icon: Symbols.graphic_eq_rounded,
      accent: AppColorsExt.of(context).brand,
      builder: (ctx) {
        final ext = AppColorsExt.of(ctx);
        final tt = Theme.of(ctx).textTheme;
        final patterns = HapticPattern.allPatterns;

        // Interleave hairline inset dividers between rows (group-card grammar).
        final rows = <Widget>[];
        for (var i = 0; i < patterns.length; i++) {
          if (i > 0) {
            rows.add(Divider(
              height: 1,
              indent: 58,
              endIndent: 12,
              color: ext.outline,
            ));
          }
          rows.add(_patternRow(ext, tt, patterns[i]));
        }
        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        );
      },
    );
  }

  /// One pattern row: neutral tile + Symbol + name + description + play button.
  Widget _patternRow(AppColorsExt ext, TextTheme tt, HapticPattern pattern) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Uniform neutral tile — same treatment as every SettingsTile.
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ext.surfaceVariant,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(_patternIcon(pattern.name),
                size: 18, color: ext.textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pattern.name,
                    style: tt.titleLarge?.copyWith(color: ext.textPrimary)),
                const SizedBox(height: 2),
                Text(pattern.description,
                    style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppIconButton(
            icon: Symbols.play_arrow_rounded,
            accent: ext.brand,
            tooltip: 'Play',
            onPressed: () => _playPattern(pattern),
          ),
        ],
      ),
    );
  }

  /// Maps a pattern name to a Material Symbol (no emoji anywhere). Covers the
  /// nine shipped patterns plus common aliases, with a safe vibration fallback.
  IconData _patternIcon(String name) {
    switch (name) {
      case 'Gentle':
        return Symbols.spa_rounded;
      case 'Standard':
        return Symbols.touch_app_rounded;
      case 'Strong':
      case 'Strong Buzz':
        return Symbols.vibration_rounded;
      case 'Double Tap':
        return Symbols.ads_click_rounded;
      case 'Triple Tap':
        return Symbols.gesture_rounded;
      case 'Tap':
        return Symbols.touch_app_rounded;
      case 'Long Press':
        return Symbols.back_hand_rounded;
      case 'Success':
        return Symbols.check_circle_rounded;
      case 'Error':
        return Symbols.error_rounded;
      case 'Breathing':
        return Symbols.air_rounded;
      case 'Celebration':
        return Symbols.celebration_rounded;
      case 'Pulse':
        return Symbols.graphic_eq_rounded;
      case 'Heartbeat':
        return Symbols.cardiology_rounded;
      case 'Sos':
        return Symbols.sos_rounded;
      default:
        return Symbols.vibration_rounded;
    }
  }

  /// Plays a short preview of the given intensity as tactile feedback.
  void _previewIntensity(HapticIntensity intensity) {
    switch (intensity) {
      case HapticIntensity.light:
        _hapticService.light();
        break;
      case HapticIntensity.medium:
        _hapticService.medium();
        break;
      case HapticIntensity.heavy:
      case HapticIntensity.custom:
        _hapticService.heavy();
        break;
    }
  }

  Future<void> _playPattern(HapticPattern pattern) async {
    for (final step in pattern.steps) {
      if (step.delay > 0) {
        await Future.delayed(Duration(milliseconds: step.delay));
      }
      switch (step.type) {
        case HapticStepType.light:
          _hapticService.light();
          break;
        case HapticStepType.medium:
          _hapticService.medium();
          break;
        case HapticStepType.heavy:
          _hapticService.heavy();
          break;
        case HapticStepType.selection:
          _hapticService.selection();
          break;
      }
    }
  }

  String _intensityLabel(HapticIntensity intensity) {
    switch (intensity) {
      case HapticIntensity.light:
        return 'Light';
      case HapticIntensity.medium:
        return 'Medium';
      case HapticIntensity.heavy:
        return 'Heavy';
      case HapticIntensity.custom:
        return 'Custom';
    }
  }
}
