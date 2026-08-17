import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/services/background_health_sync_service.dart';
import '../../../core/services/health_data_service.dart';
import '../../../core/services/health_sync_queue.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/biometric_metric.dart';
import '../models/health_source.dart';
import '../services/biometrics_service.dart';

/// Which apps and wearables are actually feeding DlyMinder.
///
/// This is the screen that makes "connect your wearable" honest. Users expect a
/// pairing flow; the truth on both platforms is that wearables connect to the
/// PHONE's health app, and DlyMinder reads from there. So rather than fake a
/// pairing UI, this lists what is genuinely contributing, per metric, with a
/// last-seen time — and says plainly where to go to add more.
///
/// Sources are listed from the registry rather than probed live: the daily
/// aggregation discards raw points, so there is nothing left to derive from
/// afterwards (see `biometrics_tables.dart`).
class ConnectedDevicesScreen extends StatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  State<ConnectedDevicesScreen> createState() => _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState extends State<ConnectedDevicesScreen>
    with WidgetsBindingObserver {
  List<HealthSource> _sources = const [];
  HealthAvailability _availability = HealthAvailability.notDetermined;

  /// Whether this device's Health Connect version supports background reads at
  /// all. When false the toggle is hidden rather than shown-and-broken.
  bool _bgAvailable = false;
  bool _bgEnabled = false;
  bool _bgBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final rows = await db.AppDatabase.instance.biometricsDao.getSources();
      final avail = await HealthDataService.instance
          .availability()
          .timeout(const Duration(seconds: 6));
      final bgAvailable =
          await HealthDataService.instance.isBackgroundReadAvailable();
      final bgEnabled = await HealthSyncQueue.isEnabled();
      if (!mounted) return;
      setState(() {
        _sources = rows.map(HealthSource.fromRow).toList();
        _availability = avail;
        _bgAvailable = bgAvailable;
        _bgEnabled = bgEnabled;
      });
    } catch (_) {
      // Keep whatever is on screen. The list is a snapshot, not a live query,
      // so a failed refresh should leave the last good one visible.
    }
  }

  Future<void> _toggle(HealthSource s, bool enabled) async {
    // Optimistic, then persist — the established pattern across the trackers.
    setState(() {
      _sources = [
        for (final x in _sources) x.id == s.id ? x.copyWith(enabled: enabled) : x
      ];
    });
    try {
      await db.AppDatabase.instance.biometricsDao
          .setSourceEnabled(s.id, enabled);
      // Re-aggregate: a disabled source must stop winning metrics it currently
      // owns, and that only takes effect on the next pass.
      await BiometricsService.syncFromHealth();
    } catch (_) {
      if (mounted) await _load(); // put the switch back where the data says
    }
  }

  Future<void> _toggleBackground(bool wanted) async {
    if (_bgBusy) return;
    setState(() => _bgBusy = true);
    try {
      if (wanted) {
        // Sends the user out to the Health Connect sheet, so the result is
        // whatever they chose there — never assume the request succeeded.
        final ok = await BackgroundHealthSyncService.instance.enable();
        if (mounted) setState(() => _bgEnabled = ok);
      } else {
        await BackgroundHealthSyncService.instance.disable();
        if (mounted) setState(() => _bgEnabled = false);
      }
    } finally {
      if (mounted) setState(() => _bgBusy = false);
    }
  }

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
              title: 'Connected devices',
              icon: Symbols.watch_rounded,
              accent: accent,
              leading: AppIconButton(
                icon: Symbols.arrow_back_rounded,
                filled: false,
                accent: accent,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: _body(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.xxl),
      children: [
        Text(
          _availability == HealthAvailability.available
              ? 'Your watch, ring or band connects to your phone\'s health app, '
                  'and DlyMinder reads from there. Anything writing data shows up '
                  'here automatically.'
              : 'Wearables connect through your phone\'s health app rather than '
                  'through DlyMinder directly.',
          style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_sources.isEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Symbols.watch_off_rounded,
                      size: 22, color: ext.mark(ext.brand)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text('Nothing connected yet',
                        style: tt.titleMedium?.copyWith(
                            color: ext.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: AppSpacing.sm),
                // Honest, and specific about what IS working. Steps keep
                // counting from the phone's own sensor with no wearable at all.
                Text(
                  'No wearable is writing to your phone\'s health app yet — or '
                  'DlyMinder has not read from it since you allowed access. '
                  'Your phone\'s own step sensor is still counting either way.',
                  style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
                ),
              ],
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [for (final s in _sources) _sourceRow(context, s)],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Turning a source off leaves its past data in place and stops it '
          'being used for new days.',
          style: tt.bodySmall?.copyWith(color: ext.textTertiary),
        ),
        // Hidden entirely when the platform cannot do it — an unavailable
        // toggle that does nothing is worse than no toggle.
        if (_bgAvailable) ...[
          const SizedBox(height: AppSpacing.xl),
          SettingsSection(
            title: 'Background sync',
            footer: 'Asks for one more Health Connect permission. Without it '
                'your data still updates every time you open DlyMinder.',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Keep syncing in the background',
                              style: tt.bodyLarge
                                  ?.copyWith(color: ext.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                              'Your steps and sleep stay current without '
                              'opening the app.',
                              style: tt.bodySmall
                                  ?.copyWith(color: ext.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppSwitch(
                      value: _bgEnabled,
                      onChanged: _bgBusy ? null : _toggleBackground,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _sourceRow(BuildContext context, HealthSource s) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    final metrics = s.contributedMetrics;
    final subtitle = [
      if (metrics.isNotEmpty)
        metrics.map(BiometricMetricKey.label).join(' · ')
      else
        'No data yet',
      _lastSeen(s.lastSeenAt),
    ].join('\n');

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.watch_rounded, size: 22, color: ext.mark(ext.brand)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.displayName,
                    style: tt.bodyLarge?.copyWith(color: ext.textPrimary)),
                if (s.deviceModel != null && s.deviceModel != s.displayName)
                  Text(s.deviceModel!,
                      style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppSwitch(
            value: s.enabled,
            onChanged: (v) => _toggle(s, v),
          ),
        ],
      ),
    );
  }

  String _lastSeen(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'Last seen just now';
    if (d.inMinutes < 60) return 'Last seen ${d.inMinutes} min ago';
    if (d.inHours < 24) {
      return 'Last seen ${d.inHours} ${d.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    return 'Last seen ${d.inDays} ${d.inDays == 1 ? 'day' : 'days'} ago';
  }
}
