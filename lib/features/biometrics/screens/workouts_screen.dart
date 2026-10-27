import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/health_windows.dart';
import '../../../core/services/health_data_service.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/workout_session.dart';
import '../services/biometrics_service.dart';
import '../widgets/biometrics_permission_card.dart';
import '../widgets/workout_detail_sheet.dart';
import '../widgets/workout_log_sheet.dart';

/// Exercise sessions: imported from Health Connect / Apple Health, and any the
/// person logged by hand — a run without the watch, a swim, a class.
///
/// Tap one for the whole session. An imported one is the watch's to change; one
/// you entered can be edited or deleted, with Undo.
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen>
    with WidgetsBindingObserver {
  HealthAvailability _availability = HealthAvailability.notDetermined;
  bool _hasGrant = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _init() async {
    await _refresh();
  }

  Future<void> _refresh() async {
    HealthAvailability avail;
    bool grant;
    try {
      final svc = HealthDataService.instance;
      avail = await svc.availability().timeout(const Duration(seconds: 6));
      grant = await svc
          .hasBiometricPermission()
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final becameUsable =
        avail == HealthAvailability.available && grant && !_hasGrant;
    if (avail != _availability || grant != _hasGrant) {
      setState(() {
        _availability = avail;
        _hasGrant = grant;
      });
    }
    if (becameUsable) await BiometricsService.syncFromHealth();
  }

  Future<void> _enable() async {
    final svc = HealthDataService.instance;
    if (_availability == HealthAvailability.needsProviderUpdate) {
      await svc.installHealthConnect();
      return;
    }
    if (_availability != HealthAvailability.available) {
      await svc.requestPermissions();
    }
    await svc.requestBiometricPermission();
    await _refresh();
    if (_hasGrant) await BiometricsService.syncFromHealth();
  }

  /// "Log a workout": the form, then the save. [existing] edits one entered
  /// earlier.
  Future<void> _logWorkout({WorkoutSession? existing}) async {
    final result = await WorkoutLogSheet.show(context, existing: existing);
    if (result == null || !mounted) return;
    final saved = await BiometricsService.saveEnteredWorkout(
      activityType: result.activityType,
      startedAt: result.startedAt,
      durationMinutes: result.durationMinutes,
      kcal: result.kcal,
      distanceKm: result.distanceKm,
      note: result.note,
      replacing: existing,
    );
    if (!mounted) return;
    context.toastSuccess(
      existing == null ? 'Workout logged' : 'Workout updated',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          if (existing == null) {
            await BiometricsService.deleteEnteredWorkout(saved.id);
          } else {
            if (saved.id != existing.id) {
              await BiometricsService.deleteEnteredWorkout(saved.id);
            }
            await BiometricsService.restoreEnteredWorkout(existing);
          }
        },
      ),
    );
  }

  /// A workout in full — and, for one you entered, the way to change or remove it.
  Future<void> _openWorkout(WorkoutSession w) async {
    final action = await WorkoutDetailSheet.show(context, w);
    if (action == null || !mounted) return;
    switch (action) {
      case WorkoutDetailAction.edit:
        await _logWorkout(existing: w);
      case WorkoutDetailAction.delete:
        await BiometricsService.deleteEnteredWorkout(w.id);
        if (!mounted) return;
        context.toastSuccess(
          'Workout deleted',
          action: AppToastAction(
            label: 'Undo',
            onPressed: () => BiometricsService.restoreEnteredWorkout(w),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {

    return AccentScope(
      feature: FeatureAccent.steps,
      child: AppScaffold(
        floatingActionButton: AppFab(
          icon: Symbols.add_rounded,
          onPressed: _logWorkout,
        ),
        body: Column(
          children: [
            AppHeader(
              title: 'Workouts',
              leading: AppHeader.backButton(context),
            ),
            Expanded(
              child: ValueListenableBuilder<Map<String, List<WorkoutSession>>>(
                      valueListenable: BiometricsService.listenToWorkouts(),
                      builder: (context, byDay, __) => _body(context, byDay),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
      BuildContext context, Map<String, List<WorkoutSession>> byDay) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    // Newest first. Keys are yyyy-MM-dd, so a plain reverse string sort is a
    // date sort — that is the whole reason the format is zero-padded.
    final keys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final usable = _availability == HealthAvailability.available && _hasGrant;

    return RefreshIndicator(
      onRefresh: () => BiometricsService.syncFromHealth(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md,
            AppSpacing.gutter, AppSpacing.xxl),
        children: [
          if (!usable || keys.isEmpty) ...[
            BiometricsPermissionCard(
              availability: _availability,
              hasBiometricGrant: _hasGrant,
              onEnable: _enable,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          for (final key in keys) ...[
            Padding(
              padding: const EdgeInsets.only(
                  bottom: AppSpacing.xs, top: AppSpacing.sm),
              child: Text(_dayLabel(key),
                  style: tt.labelLarge?.copyWith(color: ext.textSecondary)),
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                children: [
                  for (final w in byDay[key]!) _row(context, w),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _dayLabel(String dateKey) => workoutDayLabel(dateKey);

  Widget _row(BuildContext context, WorkoutSession w) {
    final ext = AppColorsExt.of(context);

    // Only the parts this session actually has. A workout with no distance
    // shows no distance, rather than "0 km".
    final parts = <String>['${w.durationMinutes} min'];
    if (w.distanceMeters != null && w.distanceMeters! > 0) {
      parts.add('${(w.distanceMeters! / 1000).toStringAsFixed(2)} km');
    }
    if (w.energyKcal != null && w.energyKcal! > 0) {
      parts.add('${w.energyKcal} kcal');
    }
    if (w.avgHr != null) parts.add('${w.avgHr} bpm avg');

    return AppListTile(
      icon: workoutIconFor(w.activityType),
      iconColor: ext.mark(ext.steps),
      title: w.activityLabel,
      subtitle: parts.join(' · '),
      onTap: () => _openWorkout(w),
    );
  }
}

/// "Today" / "Yesterday" / "Sep 26".
///
/// Anything older than yesterday used to fall through to the raw `dateKey`, so
/// the list read "2026-09-28" — a storage key shown to the user, directly above
/// rows that say "32 min · 5.20 km". [DateFormats.dayLabel] is the same
/// year-aware formatter the rest of the app groups by.
@visibleForTesting
String workoutDayLabel(String dateKey) {
  final now = clock.now();
  if (dateKey == dateKeyOf(now)) return 'Today';
  if (dateKey == dateKeyOf(previousDay(now))) return 'Yesterday';
  final parsed = DateTime.tryParse(dateKey);
  // A key that doesn't parse is better shown as-is than dropped.
  return parsed == null ? dateKey : DateFormats.dayLabel(parsed, reference: now);
}

/// The glyph for a workout type, by family.
///
/// Every row used to carry one `exercise_rounded` dumbbell, so a run, a walk and
/// a strength session were indistinguishable at a glance — the icon column
/// carried no information at all.
///
/// Matched by substring against the plugin's SCREAMING_SNAKE names, which is
/// what makes `RUNNING_TREADMILL` and `STRENGTH_TRAINING` land correctly. There
/// are 80+ of those and the list grows, so this covers the common families and
/// falls back to the generic dumbbell — the same reasoning as
/// [WorkoutSession.activityLabel], which derives a label rather than keeping a
/// map that silently goes stale.
@visibleForTesting
IconData workoutIconFor(String activityType) {
  final t = activityType.toUpperCase();
  bool has(String s) => t.contains(s);

  if (has('RUN') || has('JOG')) return Symbols.directions_run_rounded;
  if (has('WALK') || has('HIK')) return Symbols.directions_walk_rounded;
  if (has('BIK') || has('CYCL')) return Symbols.directions_bike_rounded;
  if (has('SWIM')) return Symbols.pool_rounded;
  if (has('ROW')) return Symbols.rowing_rounded;
  if (has('YOGA') || has('PILATES') || has('MEDITAT')) {
    return Symbols.self_improvement_rounded;
  }
  if (has('STRENGTH') || has('WEIGHT')) return Symbols.fitness_center_rounded;
  if (has('STAIR') || has('ELLIPTICAL')) return Symbols.stairs_rounded;
  if (has('DANC')) return Symbols.music_note_rounded;
  return Symbols.exercise_rounded;
}
