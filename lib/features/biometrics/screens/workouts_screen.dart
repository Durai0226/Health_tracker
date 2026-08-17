import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/health_windows.dart';
import '../../../core/services/health_data_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/workout_session.dart';
import '../services/biometrics_service.dart';
import '../widgets/biometrics_permission_card.dart';

/// Exercise sessions imported from Health Connect / Apple Health.
///
/// Read-only, like [HeartDashboardScreen] — the app does not offer manual
/// workout logging, so the empty state points at the wearable rather than
/// offering a form that would duplicate the watch's own.
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

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.steps;

    return AccentScope(
      feature: FeatureAccent.steps,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Workouts',
              icon: Symbols.exercise_rounded,
              accent: accent,
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                accent: accent,
                onPressed: () => Navigator.pop(context),
              ),
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

  String _dayLabel(String dateKey) {
    final today = dateKeyOf(DateTime.now());
    if (dateKey == today) return 'Today';
    if (dateKey == dateKeyOf(previousDay(DateTime.now()))) return 'Yesterday';
    return dateKey;
  }

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
      icon: Symbols.exercise_rounded,
      iconColor: ext.mark(ext.steps),
      title: w.activityLabel,
      subtitle: parts.join(' · '),
    );
  }
}
