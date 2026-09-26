import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../core/design/app_colors_ext.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/hydration_profile.dart';
import '../services/water_service.dart';
import '../services/hydration_health_sync.dart';
import '../services/hydration_weather_service.dart';
import '../../../core/health/hydration_goal.dart';
import 'package:tablet_remainder/core/widgets/app/app_toast.dart';
import '../../../core/services/health_data_service.dart';

/// Hydration Profile Screen - Calculate personalized water goal
class HydrationProfileScreen extends StatefulWidget {
  const HydrationProfileScreen({super.key});

  @override
  State<HydrationProfileScreen> createState() => _HydrationProfileScreenState();
}

class _HydrationProfileScreenState extends State<HydrationProfileScreen> {
  // Eagerly initialized so build() never reads an unassigned `late` before the
  // async _initializeProfile() completes (was a LateInitializationError on first
  // frame). WaterService overwrites it once loaded.
  HydrationProfile _profile = HydrationProfile(id: 'profile', createdAt: DateTime.now());
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();
  final _ceilingController = TextEditingController();
  final _placeController = TextEditingController();
  bool _weatherEnabled = false;
  bool _weatherBusy = false;
  String? _weatherPlace;
  bool _isSaving = false;
  bool _healthSyncEnabled = false;
  bool _healthSyncBusy = false;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    try {
      await WaterService.init();
      _profile = WaterService.getProfile();
      _weightController.text = _profile.weightKg?.toString() ?? '';
      _ageController.text = _profile.age?.toString() ?? '';
      _ceilingController.text = _profile.fluidCeilingMl?.toString() ?? '';
      _weatherEnabled = await HydrationWeatherService.isEnabled();
      _weatherPlace = await HydrationWeatherService.savedPlaceName();
      _placeController.text = _weatherPlace ?? '';
      // Reflect the STORED preference and the live OS grant together: a
      // preference saying "on" against a revoked permission must not read as on.
      final wanted = await HydrationHealthSync.isEnabled();
      _healthSyncEnabled = wanted &&
          await HealthDataService.instance.hasHydrationWritePermission();
      if (_healthSyncEnabled != wanted) {
        await HydrationHealthSync.setEnabled(_healthSyncEnabled);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing profile: $e');
      if (mounted) {
        _profile = HydrationProfile(
          id: 'profile',
          createdAt: DateTime.now(),
        );
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _ageController.dispose();
    _ceilingController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    // Validation
    if (_validateInput()) {
      setState(() => _isSaving = true);

      try {
        await WaterService.init(); // Ensure service is initialized

        final weightText = _weightController.text.trim();
        final ageText = _ageController.text.trim();

        final updated = _profile.copyWith(
          weightKg: double.tryParse(weightText),
          age: int.tryParse(ageText),
          // An emptied box means "I do not want this used", not "keep what you
          // had". `copyWith`'s `??` cannot express that, so it needs a flag —
          // the same one `clearFluidCeiling` exists for.
          clearWeight: weightText.isEmpty,
          clearAge: ageText.isEmpty,
          updatedAt: DateTime.now(),
        );

        await WaterService.saveProfile(updated);

        if (mounted) {
          context.toastSuccess('Profile saved! Daily goal: ${updated.effectiveGoalMl}ml');
          Navigator.pop(context, true);
        }
      } catch (e) {
        debugPrint('Error saving profile: $e');
        if (mounted) {
          context.toastError('Failed to save profile. Please try again.');
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  /// Bounds for a prescribed daily fluid limit.
  ///
  /// A sanity check on typing, NOT a recommendation — the app does not
  /// calculate fluid limits (see [_buildFluidRestriction]). The lower bound is
  /// well under the tightest real prescriptions (~750 ml on dialysis) and the
  /// upper one matches `HydrationGoal.maxGoalMl`, so a mistyped "15000" is
  /// caught while every clinical number is accepted.
  static const int minCeilingMl = 250;
  static const int maxCeilingMl = 5000;

  bool _validateInput() {
    final weightText = _weightController.text.trim();
    final ageText = _ageController.text.trim();
    final weight = double.tryParse(weightText);
    final age = int.tryParse(ageText);

    // Non-empty but unparseable is its own error: it used to fall through
    // `tryParse` as null and save as "no weight given" without a word.
    if (weightText.isNotEmpty && weight == null) {
      _showValidationError('Please enter a valid weight between 20-300 kg');
      return false;
    }

    if (weight != null && (weight < 20 || weight > 300)) {
      _showValidationError('Please enter a valid weight between 20-300 kg');
      return false;
    }

    if (ageText.isNotEmpty && age == null) {
      _showValidationError('Please enter a valid age between 1-120 years');
      return false;
    }

    if (age != null && (age < 1 || age > 120)) {
      _showValidationError('Please enter a valid age between 1-120 years');
      return false;
    }

    // The ceiling was accepted by `onChanged` on nothing but `ml > 0`, and was
    // never looked at again on save — so "50000" was stored as a daily fluid
    // limit, and a box left empty or mistyped silently kept whatever the last
    // valid keystroke had set.
    if (_profile.isRestricted) {
      final ceiling = int.tryParse(_ceilingController.text.trim());
      if (ceiling == null ||
          ceiling < minCeilingMl ||
          ceiling > maxCeilingMl) {
        _showValidationError(
            'Enter your daily limit in ml, between $minCeilingMl and '
            '$maxCeilingMl');
        return false;
      }
    }

    return true;
  }

  void _showValidationError(String message) {
    if (mounted) {
      context.toastWarning(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      // AppHeader. These three were the last Material `AppBar`s in the app, and
      // the reason `AppBarTheme.systemOverlayStyle` had to exist: their
      // `backgroundColor: Colors.transparent` made Flutter read the bar's
      // luminance as 0, resolve it as dark, and paint WHITE status-bar glyphs
      // over a light scaffold. `AppScaffold` declares the overlay style for
      // every screen now, so the workaround and the bar can both go.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeader(
            title: 'Hydration profile',
            leading: AppHeader.backButton(context),
          ),
          Expanded(
            child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGoalCard(),
            const SizedBox(height: 24),
            _buildPersonalInfo(),
            const SizedBox(height: 24),
            _buildActivityLevel(),
            const SizedBox(height: 24),
            _buildClimate(),
            const SizedBox(height: 24),
            _buildSpecialConditions(),
            const SizedBox(height: 16),
            _buildHealthSync(),
            const SizedBox(height: 24),
            _buildFluidRestriction(),
            const SizedBox(height: 24),
            _buildConditions(),
            const SizedBox(height: 24),
            _buildWeather(),
            const SizedBox(height: 24),
            _buildCustomGoal(),
            const SizedBox(height: 32),
            _buildSaveButton(),
            SizedBox(height: AppInsets.pushed(context)),
          ],
        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    // DS-07. This was a two-stop cyan gradient with a same-hue 15pt glow, a
    // 42pt white hero (no such step on the scale), 14/12pt white-at-80% labels
    // and a `white.withOpacity(0.15)` panel. `fillBg`/`fillFg` is the
    // AA-verified filled pair, `displayMedium` is the scale's nearest hero
    // step, and `AppCard` brings the app's own radius and shadow.
    final fill = ext.fillBg(ext.water);
    final onFill = ext.fillFg(ext.water);
    return AppCard(
      // The page Column uses CrossAxisAlignment.start, so every child is handed
      // LOOSE width constraints and a shrink-wrapping card rendered at ~59% of
      // the content width with a dead gutter down the right. AppCard passes its
      // constraints straight through, so the full-width child stays.
      color: fill,
      pressEffect: false,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Icon(Symbols.water_drop_rounded, color: onFill, size: 48),
            const SizedBox(height: AppSpacing.md),
            // Deliberately the PROFILE's goal, not today's stored one. Every
            // other surface shows the goal today is being judged against
            // (WaterService.goalForDay), because the day row carries the
            // weather adjustment and the `goalReached` flag. This card is a
            // live preview of the numbers above it — it has to move as the
            // sliders move, and re-labelling it with a temperature the user
            // cannot edit here would make the controls look broken.
            Text(
              _profile.useCustomGoal ? 'Custom Goal' : 'Recommended Goal',
              style: tt.bodyMedium?.copyWith(color: onFill),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_profile.effectiveGoalMl}ml',
              style: tt.displayMedium?.copyWith(color: onFill),
            ),
            Text(
              '${(_profile.effectiveGoalMl / 250).round()} glasses per day',
              style: tt.bodyMedium?.copyWith(color: onFill),
            ),
            // Show the working. Every competitor prints a confident number with
            // no provenance; ours is derived from published intake references
            // and a sweat model, so it can afford to be interrogated. A goal the
            // user can check is a goal they can trust — and if they disagree
            // with a term, the control that changes it is on this same screen.
            // `weightKg != null` is load-bearing, not defensive: the breakdown
            // below explains the goal term by term, and the weight term is the
            // largest of them. Without a weight there is nothing to explain and
            // `goalBreakdown().basis` describes a default the user never set.
            if (!_profile.useCustomGoal && _profile.weightKg != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: onFill.withOpacity(0.15),
                  borderRadius: AppRadius.brMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in _profile.goalBreakdown().basis)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ',
                                style:
                                    tt.bodySmall?.copyWith(color: onFill)),
                            Expanded(
                              child: Text(
                                line,
                                style:
                                    tt.bodySmall?.copyWith(color: onFill),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfo() {
    final tt = Theme.of(context).textTheme;
    return _buildSection(
      title: 'Personal Information',
      icon: Symbols.person_rounded,
      child: Column(
        // Without this the Column centres its children, which pushed the Gender
        // row off the left edge established by the Weight/Age fields above it
        // (the fields only look aligned because their Row is stretched by its
        // Expanded children).
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Weight (kg)',
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final weight = double.tryParse(value);
                    setState(() {
                      _profile = _profile.copyWith(weightKg: weight);
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  label: 'Age',
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final age = int.tryParse(value);
                    setState(() {
                      _profile = _profile.copyWith(age: age);
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Wrap, not Row: the label + both chips don't fit on one line on a
          // 320pt phone, so they flow onto a second line instead of clipping.
          // Every run starts at the card's left edge, so a wrapped second line
          // still lines up with the fields above.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('Gender:',
                    style: tt.titleMedium),
              ),
              _buildGenderChip('Male', true),
              _buildGenderChip('Female', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String label, bool isMale) {
    final ext = AppColorsExt.of(context);
    final isSelected = _profile.isMale == isMale;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _profile = _profile.copyWith(isMale: isMale);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ext.fillBg(ext.water) : ext.surfaceVariant,
          borderRadius: AppRadius.brFull,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected ? ext.fillFg(ext.water) : ext.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
        ),
      ),
    );
  }

  Widget _buildActivityLevel() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final waterMark = ext.mark(ext.water);
    return _buildSection(
      title: 'Activity Level',
      icon: Symbols.directions_run_rounded,
      child: Column(
        children: ActivityLevel.values.map((level) {
          final isSelected = _profile.activityLevel == level;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _profile = _profile.copyWith(activityLevel: level);
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? ext.water.container : ext.surfaceVariant,
                borderRadius: AppRadius.brMd,
                border: Border.all(
                  color: isSelected ? waterMark : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getActivityIcon(level),
                    color: isSelected ? ext.water.onContainer : ext.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getActivityLabel(level),
                          style: tt.titleMedium?.copyWith(
                            color: isSelected
                                ? ext.water.onContainer
                                : ext.textPrimary,
                          ),
                        ),
                        Text(
                          _getActivityDescription(level),
                          style: tt.bodySmall?.copyWith(
                            color: isSelected
                                ? ext.water.onContainer
                                : ext.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Symbols.check_circle_rounded,
                        color: ext.water.onContainer),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getActivityIcon(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return Symbols.weekend_rounded;
      case ActivityLevel.light:
        return Symbols.directions_walk_rounded;
      case ActivityLevel.moderate:
        return Symbols.directions_run_rounded;
      case ActivityLevel.active:
        return Symbols.fitness_center_rounded;
      case ActivityLevel.veryActive:
        return Symbols.sports_martial_arts_rounded;
    }
  }

  String _getActivityLabel(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Sedentary';
      case ActivityLevel.light:
        return 'Lightly Active';
      case ActivityLevel.moderate:
        return 'Moderately Active';
      case ActivityLevel.active:
        return 'Active';
      case ActivityLevel.veryActive:
        return 'Very Active';
    }
  }

  String _getActivityDescription(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Little to no exercise, desk job';
      case ActivityLevel.light:
        return 'Light exercise 1-3 days/week';
      case ActivityLevel.moderate:
        return 'Moderate exercise 3-5 days/week';
      case ActivityLevel.active:
        return 'Hard exercise 6-7 days/week';
      case ActivityLevel.veryActive:
        return 'Very hard exercise, physical job';
    }
  }

  Widget _buildClimate() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final waterMark = ext.mark(ext.water);
    return _buildSection(
      title: 'Climate',
      icon: Symbols.thermostat_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ClimateType.values.map((climate) {
          final isSelected = _profile.climate == climate;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _profile = _profile.copyWith(climate: climate);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? ext.water.container : ext.surfaceVariant,
                borderRadius: AppRadius.brMd,
                border: Border.all(
                  color: isSelected ? waterMark : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // DS-17: a 20pt emoji inside a bordered chip is chrome.
                  Icon(
                    _getClimateIcon(climate),
                    size: 20,
                    color: isSelected
                        ? ext.water.onContainer
                        : ext.textSecondary,
                    applyTextScaling: false,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // 'Very Hot (>35°C)' is wider than a 320pt card at large text
                  // sizes; Flexible bounds the label so the chip can't overflow.
                  Flexible(
                    child: Text(
                      _getClimateLabel(climate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? ext.water.onContainer
                            : ext.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getClimateIcon(ClimateType climate) {
    switch (climate) {
      case ClimateType.cold:
        return Symbols.ac_unit_rounded;
      case ClimateType.moderate:
        return Symbols.partly_cloudy_day_rounded;
      case ClimateType.warm:
        return Symbols.wb_sunny_rounded;
      case ClimateType.hot:
        return Symbols.local_fire_department_rounded;
      case ClimateType.veryHot:
        return Symbols.whatshot_rounded;
    }
  }

  String _getClimateLabel(ClimateType climate) {
    switch (climate) {
      case ClimateType.cold:
        return 'Cold (<10°C)';
      case ClimateType.moderate:
        return 'Moderate';
      case ClimateType.warm:
        return 'Warm';
      case ClimateType.hot:
        return 'Hot';
      case ClimateType.veryHot:
        return 'Very Hot (>35°C)';
    }
  }

  Widget _buildSpecialConditions() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return _buildSection(
      title: 'Special Conditions',
      icon: Symbols.favorite_rounded,
      child: Column(
        children: [
          if (!_profile.isMale) ...[
            _buildToggleRow(
              label: 'Pregnant',
              icon: Symbols.pregnant_woman_rounded,
              value: _profile.isPregnant,
              onChanged: (value) {
                setState(() {
                  _profile = _profile.copyWith(isPregnant: value);
                });
              },
            ),
            const SizedBox(height: 12),
            _buildToggleRow(
              label: 'Breastfeeding',
              icon: Symbols.child_care_rounded,
              value: _profile.isBreastfeeding,
              onChanged: (value) {
                setState(() {
                  _profile = _profile.copyWith(isBreastfeeding: value);
                });
              },
            ),
          ],
          if (_profile.isMale)
            Center(
              child: Text(
                'No special conditions applicable',
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  /// Opt-in write-through to Health Connect / HealthKit.
  ///
  /// Deliberately a live platform-permission toggle rather than a stored
  /// preference alone: flipping it on without the OS grant would leave the
  /// switch reading "on" while nothing was ever written, which is the exact
  /// failure users report against the competition.
  Widget _buildHealthSync() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return _buildSection(
      title: 'Health Connect',
      icon: Symbols.sync_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToggleRow(
            label: 'Share drinks with other health apps',
            icon: Symbols.water_drop_rounded,
            value: _healthSyncEnabled,
            onChanged: _healthSyncBusy ? (_) {} : _setHealthSync,
          ),
          const SizedBox(height: 8),
          Text(
            _healthSyncEnabled
                ? 'New drinks are written to your phone’s health store, so '
                    'Samsung Health, Fitbit and Apple Health can see them. Only '
                    'the amount and the time — not the drink type.'
                : 'Off. Drinks you log stay in this app only.',
            style: tt.bodySmall?.copyWith(color: ext.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _setHealthSync(bool enabled) async {
    setState(() => _healthSyncBusy = true);
    try {
      if (!enabled) {
        await HydrationHealthSync.setEnabled(false);
        if (mounted) setState(() => _healthSyncEnabled = false);
        return;
      }

      // Ask the OS first. Only persist "on" if the grant actually landed —
      // requestAuthorization returning true means the sheet was shown, not that
      // access was given.
      final granted = await HydrationHealthSync.requestPermission();
      if (!mounted) return;
      if (granted) {
        await HydrationHealthSync.setEnabled(true);
        if (mounted) setState(() => _healthSyncEnabled = true);
      } else {
        setState(() => _healthSyncEnabled = false);
        if (mounted) {
          context.toastWarning(
              'Health Connect did not grant permission to write hydration');
        }
      }
    } finally {
      if (mounted) setState(() => _healthSyncBusy = false);
    }
  }

  /// Prescribed fluid ceiling.
  ///
  /// Framed throughout as *your clinician's number*, never as something the app
  /// recommends or calculates. The app has no business suggesting a fluid limit
  /// — it only has business not contradicting one.
  Widget _buildFluidRestriction() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final on = _profile.isRestricted;
    return _buildSection(
      title: 'Fluid restriction',
      icon: Symbols.medical_information_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToggleRow(
            label: 'I have a daily fluid limit',
            icon: Symbols.clinical_notes_rounded,
            value: on,
            onChanged: (value) {
              setState(() {
                _profile = value
                    ? _profile.copyWith(
                        fluidCeilingMl: _profile.fluidCeilingMl ?? 1500)
                    : _profile.copyWith(clearFluidCeiling: true);
              });
              _ceilingController.text =
                  _profile.fluidCeilingMl?.toString() ?? '';
            },
          ),
          const SizedBox(height: 8),
          Text(
            on
                ? 'Your daily number is a limit to stay under, not a target. '
                    'Reminders to drink are switched off, the dial counts down, '
                    'and nothing rewards you for going over.'
                : 'Some people — on dialysis, in advanced kidney disease, or '
                    'with heart failure — are told to cap how much they drink. '
                    'Turn this on and the app stops pushing you to drink more.',
            style: tt.bodySmall?.copyWith(color: ext.textSecondary),
          ),
          if (on) ...[
            const SizedBox(height: 16),
            _buildTextField(
              controller: _ceilingController,
              label: 'Daily limit (ml)',
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final ml = int.tryParse(v);
                if (ml != null && ml > 0) {
                  setState(() =>
                      _profile = _profile.copyWith(fluidCeilingMl: ml));
                }
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ext.warning.container,
                borderRadius: AppRadius.brMd,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Symbols.info_rounded,
                      size: 16, color: ext.mark(ext.warning)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use the number your clinician gave you. This app does '
                      'not calculate fluid limits and is not medical advice.',
                      style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Conditions with published support for drinking more.
  ///
  /// Hidden entirely under a fluid restriction: offering "drink 3 L for your
  /// kidney stones" to someone on a dialysis fluid limit is exactly the
  /// contradiction this whole section has to avoid. The limit wins, and the app
  /// should not even suggest otherwise.
  Widget _buildConditions() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    if (_profile.isRestricted) {
      return _buildSection(
        title: 'Health conditions',
        icon: Symbols.clinical_notes_rounded,
        child: Text(
          'Not shown while a fluid limit is set — your limit takes priority '
          'over anything that would raise your intake.',
          style: tt.bodySmall?.copyWith(color: ext.textSecondary),
        ),
      );
    }

    return _buildSection(
      title: 'Health conditions',
      icon: Symbols.clinical_notes_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'If any of these apply, your target changes to match published '
            'guidance. Nothing here is medical advice.',
            style: tt.bodySmall?.copyWith(color: ext.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final c in HydrationCondition.values) ...[
            _buildToggleRow(
              label: hydrationConditionRules[c]!.label,
              icon: Symbols.clinical_notes_rounded,
              value: _profile.conditions.contains(c),
              onChanged: (on) {
                setState(() {
                  final next = {..._profile.conditions};
                  on ? next.add(c) : next.remove(c);
                  _profile = _profile.copyWith(conditions: next);
                });
              },
            ),
            if (_profile.conditions.contains(c)) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  hydrationConditionRules[c]!.basis,
                  style: tt.labelSmall?.copyWith(color: ext.textSecondary),
                ),
              ),
              // Weak evidence is labelled as weak. Presenting an observational
              // case-crossover study with the same confidence as a randomised
              // trial is worse than not shipping the feature.
              if (hydrationConditionRules[c]!.caveat.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Symbols.warning_rounded,
                          size: 14, color: ext.mark(ext.warning)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hydrationConditionRules[c]!.caveat,
                          style: tt.labelSmall
                              ?.copyWith(color: ext.mark(ext.warning)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  /// Auto-weather. Opt-in, and notably without a location permission — the user
  /// names their city once. Hydro Coach's equivalent flagship feature takes
  /// coarse location; typing "Chennai" once is a better trade for a health app.
  Widget _buildWeather() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    if (_profile.isRestricted) return const SizedBox.shrink();

    return _buildSection(
      title: 'Adjust for the weather',
      icon: Symbols.thermostat_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToggleRow(
            label: 'Raise my goal on hot days',
            icon: Symbols.thermostat_rounded,
            value: _weatherEnabled,
            onChanged: _weatherBusy ? (_) {} : _setWeatherEnabled,
          ),
          const SizedBox(height: 8),
          Text(
            _weatherPlace == null
                ? 'Name your town or city once and the app checks the '
                    'feels-like temperature. No location permission — nothing '
                    'but the name you type leaves the device.'
                : 'Using $_weatherPlace.',
            style: tt.bodySmall?.copyWith(color: ext.textSecondary),
          ),
          if (_weatherEnabled) ...[
            const SizedBox(height: 16),
            _buildTextField(
              controller: _placeController,
              label: 'Town or city',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    HydrationWeatherService.attribution,
                    style: tt.labelSmall?.copyWith(color: ext.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: _weatherBusy ? null : _resolvePlace,
                  child: Text(_weatherBusy ? 'Checking…' : 'Use this place'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setWeatherEnabled(bool enabled) async {
    await HydrationWeatherService.setEnabled(enabled);
    if (!mounted) return;
    setState(() => _weatherEnabled = enabled);
    if (enabled && _weatherPlace != null) _refreshWeather();
  }

  Future<void> _resolvePlace() async {
    final query = _placeController.text.trim();
    if (query.isEmpty) return;
    setState(() => _weatherBusy = true);
    final resolved = await HydrationWeatherService.setPlace(query);
    if (!mounted) return;
    setState(() {
      _weatherBusy = false;
      _weatherPlace = resolved;
    });
    if (resolved == null) {
      // Not an error — the place just was not found.
      context.toastWarning('Could not find "$query" — try a nearby city');
      return;
    }
    _placeController.text = resolved;
    await _refreshWeather();
  }

  Future<void> _refreshWeather() async {
    final w = await HydrationWeatherService.current(force: true);
    if (!mounted) return;
    if (w == null) {
      context.toastWarning('Could not reach the weather service just now');
      return;
    }
    await WaterService.refreshWeatherGoal();
    if (!mounted) return;
    // Re-read the profile-derived goal so the hero card updates.
    setState(() {});
    context.toastSuccess(
        'It feels like ${w.apparentC.round()}°C in ${w.placeName}');
  }

  Widget _buildToggleRow({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    // Two fixes, and the first is the worst instance of it in the app.
    //
    // The OFF background was `ext.surfaceVariant` — the same token the switch's
    // own off track uses. Control and background were byte-identical, 1.000:1,
    // with only a sub-1.3:1 outline between them. `surface` puts the track back
    // on a different colour, and the switch's outline (now `textTertiary`, at
    // 3.78:1) carries the boundary.
    //
    // Second: the whole row toggles, and it is one semantics node. That is the
    // house rule 23 SettingsTile rows follow, and these six did not.
    //
    // The leading was an EMOJI at 24pt (💧 ⚕️ 🌡️ 🤰 🤱) — chrome, by DS-17 —
    // and it is an `IconData` now, which is also the one thing that used to
    // block migrating these six rows onto `SettingsTile`. That migration is
    // deliberately NOT part of this pass: `responsive_overflow_test` gates
    // SettingsTile row-cuts against a per-screen baseline, and adding tiles to
    // a screen with no entry there fails the gate on a conformance change.
    return MergeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: AppRadius.brMd,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: value ? ext.water.container : ext.surface,
              borderRadius: AppRadius.brMd,
              border: Border.all(
                  color: value ? Colors.transparent : ext.outline),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 24,
                    color: value ? ext.water.onContainer : ext.textSecondary,
                    applyTextScaling: false),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(
                        color: value
                            ? ext.water.onContainer
                            : ext.textPrimary),
                  ),
                ),
                const SizedBox(width: AppRowMetrics.trailingGap),
                AppSwitch(
                  value: value,
                  onChanged: onChanged,
                  accent: ext.water,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomGoal() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return _buildSection(
      title: 'Custom Goal',
      icon: Symbols.tune_rounded,
      child: Column(
        children: [
          // Row-tap toggles, one semantics node — the same rule applied to the
          // toggle rows above.
          MergeSemantics(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _profile = _profile
                    .copyWith(useCustomGoal: !_profile.useCustomGoal)),
                borderRadius: AppRadius.brSm,
                child: Row(
            children: [
              Expanded(
                child: Text(
                  'Use custom goal instead of calculated',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                ),
              ),
              const SizedBox(width: AppRowMetrics.trailingGap),
              AppSwitch(
                value: _profile.useCustomGoal,
                onChanged: (value) {
                  setState(() {
                    _profile = _profile.copyWith(useCustomGoal: value);
                  });
                },
                accent: ext.water,
              ),
            ],
                ),
              ),
            ),
          ),
          if (_profile.useCustomGoal) ...[
            const SizedBox(height: AppSpacing.lg),
            // AppStepper — the shared control that replaced three copies of
            // this exact -/+ row (two of which had untooltipped icon buttons).
            AppStepper(
              value: '${_profile.customGoalMl}ml',
              accent: ext.water,
              decrementTooltip: 'Decrease goal by 250 ml',
              incrementTooltip: 'Increase goal by 250 ml',
              onDecrement: _profile.customGoalMl <= 500
                  ? null
                  : () => setState(() => _profile = _profile.copyWith(
                      customGoalMl:
                          (_profile.customGoalMl - 250).clamp(500, 5000))),
              onIncrement: _profile.customGoalMl >= 5000
                  ? null
                  : () => setState(() => _profile = _profile.copyWith(
                      customGoalMl:
                          (_profile.customGoalMl + 250).clamp(500, 5000))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final ext = AppColorsExt.of(context);
    // DS-20/22: was a `Container` with its own BoxShadow and a bold 16pt title
    // row. `SectionHeader` already renders an accent icon chip + heading, marks
    // the heading as a semantic header (so TalkBack/VoiceOver can jump between
    // the ten sections on this screen), and sizes the title from the scale.
    return AppCard(
      pressEffect: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, icon: icon, accent: ext.water),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    final ext = AppColorsExt.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: ext.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(borderRadius: AppRadius.brMd),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: ext.mark(ext.water), width: 2),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    // W13: a raw `ElevatedButton` with its own 56pt SizedBox, its own
    // RoundedRectangleBorder and a hand-rolled CircularProgressIndicator for
    // the saving state. `AppButton` is that button, and its `loading` flag is
    // that spinner.
    return AppButton(
      label: 'Save Profile',
      size: AppButtonSize.lg,
      fullWidth: true,
      loading: _isSaving,
      accent: AppColorsExt.of(context).water,
      onPressed: _isSaving ? null : _save,
    );
  }
}
