import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/services/vitavibe_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../settings/screens/early_access_screen.dart';

/// Advanced haptic patterns ("Haptix").
///
/// Rebuilt on the modern design system. The previous version hardcoded
/// `Color(0xFF2D3142)` for every row title, which rendered near-black on the
/// dark background and made the screen effectively unreadable in dark mode; it
/// also used a teal [AppBar] whose title inherited no colour, so the header
/// text was black-on-teal in light mode. Everything here goes through
/// [AppColorsExt] so both themes are correct by construction.
class VitaVibeSettingsScreen extends StatefulWidget {
  const VitaVibeSettingsScreen({super.key});

  @override
  State<VitaVibeSettingsScreen> createState() => _VitaVibeSettingsScreenState();
}

class _VitaVibeSettingsScreenState extends State<VitaVibeSettingsScreen> {
  final _service = VitaVibeService();

  /// The service keys a pattern per *feature group*, not per row — several
  /// rows deliberately share a key (both medicine rows map to `medicine`,
  /// and the two "goal reached" rows map to `celebrate`).
  static const List<_FeatureRow> _features = [
    _FeatureRow('medicine', 'Medicine taken', Symbols.medication_rounded),
    _FeatureRow('medicine', 'Medicine reminder', Symbols.alarm_rounded),
    _FeatureRow('water', 'Water added', Symbols.water_drop_rounded),
    _FeatureRow('celebrate', 'Goal reached', Symbols.emoji_events_rounded),
    _FeatureRow('focus', 'Focus start', Symbols.center_focus_strong_rounded),
    _FeatureRow('navigation', 'Navigation', Symbols.swipe_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;

    return AccentScope(
      feature: FeatureAccent.brand,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Haptix',
              icon: Symbols.vibration_rounded,
              accent: accent,
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _service,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  children: _buildBody(ext, accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody(AppColorsExt ext, AccentSwatch accent) {
    final enabled = _service.isEnabled;

    return [
      SettingsSection(
        footer: 'Richer vibration patterns for reminders, goals and taps. '
            'Separate from the basic Haptic Feedback setting.',
        children: [
          SettingsTile(
            icon: Symbols.vibration_rounded,
            title: 'Haptix',
            subtitle: enabled ? 'On' : 'Off',
            accent: accent,
            switchValue: enabled,
            onSwitchChanged: (value) => _service.toggleEnabled(value),
          ),
        ],
      ),
      if (enabled) ...[
        const SizedBox(height: AppSpacing.lg),
        _buildIntensityCard(ext, accent),
        const SizedBox(height: AppSpacing.lg),
        SettingsSection(
          title: 'Feature patterns',
          footer: 'Tap a row to choose which pattern plays for that event.',
          children: [
            for (final f in _features)
              SettingsTile(
                icon: f.icon,
                title: f.title,
                value: _patternLabel(_service.getPatternForFeature(f.key)),
                accent: accent,
                onTap: () => _showPatternSelector(f),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsSection(
          title: 'More',
          children: [
            SettingsTile(
              icon: Symbols.graphic_eq_rounded,
              title: 'Pattern explorer',
              subtitle: 'Preview all ${VibePattern.values.length} patterns',
              accent: accent,
              onTap: _showPatternExplorer,
            ),
            SettingsTile(
              icon: Symbols.science_rounded,
              title: 'Early access',
              subtitle: 'Try experimental features',
              accent: accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EarlyAccessScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  Widget _buildIntensityCard(AppColorsExt ext, AccentSwatch accent) {
    final intensity = _service.intensity;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.tune_rounded, size: 20, color: ext.mark(accent)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Intensity',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ext.textPrimary,
                  ),
                ),
              ),
              // Flexible so the longest label ("Ultra strong") can't push the
              // row past the card at 320pt / large Dynamic Type — AppChip
              // already ellipsizes once its width is bounded.
              Flexible(
                child: AppChip(
                  label: _intensityLabel(intensity),
                  accent: accent,
                  selected: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Slider(
            value: intensity.index.toDouble(),
            min: 0,
            max: (VibeIntensity.values.length - 1).toDouble(),
            divisions: VibeIntensity.values.length - 1,
            label: _intensityLabel(intensity),
            activeColor: ext.mark(accent),
            onChanged: (value) =>
                _service.setIntensity(VibeIntensity.values[value.toInt()]),
          ),
          // The slider's end labels are two unflexed Texts in a bounded Row;
          // "Ultra light" + "Ultra strong" overran the card on a 320pt phone
          // (and on every width at 1.3x text). Flexible + ellipsis keeps them
          // pinned to their ends and lets them give way instead of overflowing.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  _intensityLabel(VibeIntensity.values.first),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: ext.textTertiary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  _intensityLabel(VibeIntensity.values.last),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12, color: ext.textTertiary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showPatternSelector(_FeatureRow feature) async {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;

    await AppBottomSheet.show<void>(
      context,
      title: feature.title,
      icon: feature.icon,
      accent: accent,
      builder: (sheetContext) => ListenableBuilder(
        listenable: _service,
        builder: (context, _) {
          final current = _service.getPatternForFeature(feature.key);
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final category in VibeCategory.values)
                  ..._categorySection(ext, accent, category, current, feature),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _categorySection(
    AppColorsExt ext,
    AccentSwatch accent,
    VibeCategory category,
    VibePattern current,
    _FeatureRow feature,
  ) {
    final patterns = _patternsIn(category);
    if (patterns.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Text(
          _categoryLabel(category).toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: ext.textTertiary,
          ),
        ),
      ),
      for (final pattern in patterns)
        AppListTile(
          icon: _categoryIcon(category),
          iconColor: pattern == current ? ext.mark(accent) : ext.textSecondary,
          title: _patternLabel(pattern),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconButton(
                icon: Symbols.play_arrow_rounded,
                filled: false,
                onPressed: () => _service.playPattern(pattern),
              ),
              if (pattern == current)
                Icon(
                  Symbols.check_circle_rounded,
                  size: 20,
                  color: ext.mark(accent),
                ),
            ],
          ),
          onTap: () {
            _service.setFeaturePattern(feature.key, pattern);
            _service.playPattern(pattern);
          },
        ),
    ];
  }

  Future<void> _showPatternExplorer() async {
    final ext = AppColorsExt.of(context);
    final accent = ext.brand;

    await AppBottomSheet.show<void>(
      context,
      title: 'Pattern explorer',
      icon: Symbols.graphic_eq_rounded,
      accent: accent,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final category in VibeCategory.values) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Text(
                  _categoryLabel(category).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: ext.textTertiary,
                  ),
                ),
              ),
              for (final pattern in _patternsIn(category))
                AppListTile(
                  icon: _categoryIcon(category),
                  iconColor: ext.textSecondary,
                  title: _patternLabel(pattern),
                  trailing: AppIconButton(
                    icon: Symbols.play_arrow_rounded,
                    filled: false,
                    onPressed: () => _service.playPattern(pattern),
                  ),
                  onTap: () => _service.playPattern(pattern),
                ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  // ---- Static maps -------------------------------------------------------

  /// The enum is declared in category order, so a category is a contiguous
  /// run. Keeping the boundaries explicit avoids relying on index maths.
  static List<VibePattern> _patternsIn(VibeCategory category) {
    switch (category) {
      case VibeCategory.basic:
        return const [
          VibePattern.tap,
          VibePattern.doubleTap,
          VibePattern.tripleTap,
          VibePattern.longPress,
          VibePattern.strongBuzz,
        ];
      case VibeCategory.rhythmic:
        return const [
          VibePattern.heartbeat,
          VibePattern.pulse,
          VibePattern.sos,
          VibePattern.drumroll,
          VibePattern.tickTock,
        ];
      case VibeCategory.nature:
        return const [
          VibePattern.raindrops,
          VibePattern.oceanWave,
          VibePattern.thunder,
          VibePattern.birdChirp,
          VibePattern.catPurr,
        ];
      case VibeCategory.alert:
        return const [
          VibePattern.alert,
          VibePattern.reminder,
          VibePattern.urgentAlert,
          VibePattern.medicineTime,
          VibePattern.waterReminder,
        ];
      case VibeCategory.relaxation:
        return const [
          VibePattern.breathingGuide,
          VibePattern.massage,
          VibePattern.meditationBell,
          VibePattern.sleepyWave,
          VibePattern.calmBreeze,
        ];
      case VibeCategory.celebration:
        return const [
          VibePattern.success,
          VibePattern.celebration,
          VibePattern.fanfare,
          VibePattern.fireworks,
          VibePattern.goalReached,
        ];
    }
  }

  static String _categoryLabel(VibeCategory category) => switch (category) {
        VibeCategory.basic => 'Basic',
        VibeCategory.rhythmic => 'Rhythmic',
        VibeCategory.nature => 'Nature',
        VibeCategory.alert => 'Alerts',
        VibeCategory.relaxation => 'Relaxation',
        VibeCategory.celebration => 'Celebration',
      };

  static IconData _categoryIcon(VibeCategory category) => switch (category) {
        VibeCategory.basic => Symbols.touch_app_rounded,
        VibeCategory.rhythmic => Symbols.graphic_eq_rounded,
        VibeCategory.nature => Symbols.eco_rounded,
        VibeCategory.alert => Symbols.notifications_active_rounded,
        VibeCategory.relaxation => Symbols.spa_rounded,
        VibeCategory.celebration => Symbols.celebration_rounded,
      };

  static String _intensityLabel(VibeIntensity intensity) => switch (intensity) {
        VibeIntensity.ultraLight => 'Ultra light',
        VibeIntensity.light => 'Light',
        VibeIntensity.medium => 'Medium',
        VibeIntensity.strong => 'Strong',
        VibeIntensity.ultraStrong => 'Ultra strong',
      };

  static String _patternLabel(VibePattern pattern) => switch (pattern) {
        VibePattern.tap => 'Tap',
        VibePattern.doubleTap => 'Double tap',
        VibePattern.tripleTap => 'Triple tap',
        VibePattern.longPress => 'Long press',
        VibePattern.strongBuzz => 'Strong buzz',
        VibePattern.heartbeat => 'Heartbeat',
        VibePattern.pulse => 'Pulse',
        VibePattern.sos => 'SOS',
        VibePattern.drumroll => 'Drumroll',
        VibePattern.tickTock => 'Tick tock',
        VibePattern.raindrops => 'Raindrops',
        VibePattern.oceanWave => 'Ocean wave',
        VibePattern.thunder => 'Thunder',
        VibePattern.birdChirp => 'Bird chirp',
        VibePattern.catPurr => 'Cat purr',
        VibePattern.alert => 'Alert',
        VibePattern.reminder => 'Reminder',
        VibePattern.urgentAlert => 'Urgent alert',
        VibePattern.medicineTime => 'Medicine time',
        VibePattern.waterReminder => 'Water reminder',
        VibePattern.breathingGuide => 'Breathing guide',
        VibePattern.massage => 'Massage',
        VibePattern.meditationBell => 'Meditation bell',
        VibePattern.sleepyWave => 'Sleepy wave',
        VibePattern.calmBreeze => 'Calm breeze',
        VibePattern.success => 'Success',
        VibePattern.celebration => 'Celebration',
        VibePattern.fanfare => 'Fanfare',
        VibePattern.fireworks => 'Fireworks',
        VibePattern.goalReached => 'Goal reached',
      };
}

class _FeatureRow {
  final String key;
  final String title;
  final IconData icon;

  const _FeatureRow(this.key, this.title, this.icon);
}
