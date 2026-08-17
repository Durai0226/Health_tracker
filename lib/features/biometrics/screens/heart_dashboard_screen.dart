import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/health_data_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/biometric_day.dart';
import '../models/biometric_metric.dart';
import '../services/biometrics_service.dart';
import '../widgets/biometrics_permission_card.dart';

/// Resting heart rate, heart-rate variability, blood oxygen and breathing rate
/// — one screen rather than four thin trackers, because most users will have
/// only some of these and four near-empty tiles is worse information
/// architecture (and four times the cost in both test registries).
///
/// Everything here is read-only. Nothing on this screen can be hand-entered:
/// nobody types a day of heart-rate samples, so the honest empty state is
/// "connect a wearable", not a manual-entry form.
class HeartDashboardScreen extends StatefulWidget {
  const HeartDashboardScreen({super.key});

  @override
  State<HeartDashboardScreen> createState() => _HeartDashboardScreenState();
}

class _HeartDashboardScreenState extends State<HeartDashboardScreen>
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

  /// Health access is granted on a screen we do not own, so resume is the only
  /// reliable moment to notice it. Doubly true here: the wearable tier is a
  /// SECOND trip out to the Health Connect sheet, so the user leaves and comes
  /// back twice.
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
      // Bounded, like the Steps screen: never leave the user on an infinite
      // spinner if the platform probe hangs.
      avail = await svc.availability().timeout(const Duration(seconds: 6));
      grant = await svc
          .hasBiometricPermission()
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      return; // keep what we had; never downgrade on a transient failure
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
    // The base grant has to exist before the wearable tier can be asked for.
    if (_availability != HealthAvailability.available) {
      await svc.requestPermissions();
    }
    await svc.requestBiometricPermission();
    // Re-check rather than trusting the return value: on iOS
    // requestAuthorization reports true whenever the sheet closed without an
    // error, whether or not anything was actually allowed.
    await _refresh();
    if (_hasGrant) await BiometricsService.syncFromHealth();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final accent = ext.medicine;

    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Heart',
              icon: Symbols.ecg_heart_rounded,
              accent: accent,
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                accent: accent,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<Map<String, BiometricDay>>(
                      valueListenable: BiometricsService.listenToDays(),
                      builder: (context, _, __) => _body(context),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final today = BiometricsService.getToday();
    final restingTrend = BiometricsService.restingHrTrend();
    final baseline = BiometricsService.hrvBaseline();

    final usable = _availability == HealthAvailability.available && _hasGrant;
    final hasAnything = today != null || restingTrend.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () => BiometricsService.syncFromHealth(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md,
            AppSpacing.gutter, AppSpacing.xxl),
        children: [
          if (!usable || !hasAnything) ...[
            BiometricsPermissionCard(
              availability: _availability,
              hasBiometricGrant: _hasGrant,
              onEnable: _enable,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (hasAnything) ...[
            _todayCard(context, today),
            const SizedBox(height: AppSpacing.lg),
            _restingCard(context, restingTrend),
            const SizedBox(height: AppSpacing.lg),
            _hrvCard(context, baseline),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Heart data is read from your phone\'s health app. DlyMinder never '
            'writes it back, and it stays on this device unless you turn on '
            'cloud sync.',
            style: tt.bodySmall?.copyWith(color: ext.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _todayCard(BuildContext context, BiometricDay? day) {
    final ext = AppColorsExt.of(context);
    final accent = ext.medicine;

    // Every tile is nullable all the way to the screen. An absent metric shows
    // an em dash — never a zero, which would be a measured claim.
    String bpm(int? v) => v == null ? '—' : '$v';
    String pct(double? v) => v == null ? '—' : v.toStringAsFixed(0);
    String rate(double? v) => v == null ? '—' : v.toStringAsFixed(0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: ext.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          StatTileRow(tiles: [
            StatTile(
              icon: Symbols.ecg_heart_rounded,
              value: bpm(day?.restingHr),
              label: day?.restingHrDerived == true ? 'Resting (est.)' : 'Resting',
              accent: accent,
            ),
            StatTile(
              icon: Symbols.favorite_rounded,
              value: day?.hrMin == null || day?.hrMax == null
                  ? '—'
                  : '${day!.hrMin}–${day.hrMax}',
              label: 'Range',
              accent: accent,
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          StatTileRow(tiles: [
            StatTile(
              icon: Symbols.spo2_rounded,
              value: pct(day?.spo2Avg),
              label: 'Blood oxygen %',
              accent: accent,
            ),
            StatTile(
              icon: Symbols.pulmonology_rounded,
              value: rate(day?.respiratoryRateAvg),
              label: 'Breaths / min',
              accent: accent,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _restingCard(
      BuildContext context,
      List<({DateTime date, int bpm, bool derived})> trend) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    if (trend.isEmpty) {
      return AppCard(
        child: Text('No resting heart rate recorded in the last 30 days.',
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
      );
    }

    final values = trend.map((e) => e.bpm).toList();
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final avg = (values.reduce((a, b) => a + b) / values.length).round();
    final anyDerived = trend.any((e) => e.derived);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resting heart rate',
              style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text('$avg bpm average over ${trend.length} '
              '${trend.length == 1 ? 'day' : 'days'} · $lo–$hi',
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
          if (anyDerived) ...[
            const SizedBox(height: AppSpacing.xs),
            // Said plainly rather than buried: some of these were inferred from
            // overnight heart rate because the wearable did not report a
            // resting value of its own.
            Text('Some days are estimated from your overnight heart rate.',
                style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
          ],
        ],
      ),
    );
  }

  Widget _hrvCard(BuildContext context,
      ({double? ms, HrvMetric? metric, int nights}) baseline) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    if (baseline.metric == null) {
      return AppCard(
        child: Text('No heart-rate variability recorded yet.',
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
      );
    }

    // Below the minimum nights the baseline is null on purpose — an average
    // over two nights is noise wearing a number's clothes, and this app does
    // not print figures it cannot stand behind.
    final body = baseline.ms == null
        ? 'Needs a few more nights before a baseline means anything '
            '(${baseline.nights} so far).'
        : '${baseline.ms!.round()} ms average over ${baseline.nights} nights.';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Heart-rate variability',
              style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          // The metric is named because Android reports RMSSD and iOS SDNN.
          // They are different statistics over different ranges, so a number
          // without its metric is not comparable to one from another phone.
          Text(
            baseline.metric == HrvMetric.rmssd
                ? 'Measured as RMSSD, from Health Connect.'
                : 'Measured as SDNN, from Apple Health.',
            style: tt.bodySmall?.copyWith(color: ext.textTertiary),
          ),
        ],
      ),
    );
  }
}
