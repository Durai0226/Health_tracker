import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/services/health_data_service.dart';
import '../../../core/services/health_sync_queue.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/biometric_metric.dart';
import '../models/health_source.dart';
import '../services/connected_devices_controller.dart';
import 'health_source_detail_screen.dart';

/// Which apps and wearables are actually feeding DlyMinder.
///
/// This is the screen that makes "connect your wearable" honest. Users expect a
/// pairing flow; the truth on both platforms is that wearables connect to the
/// PHONE's health app and DlyMinder reads from there. So rather than fake a
/// pairing UI, this lists what is genuinely contributing, per metric, with a
/// last-seen time — and says plainly where to go to add more.
///
/// Sources come from the registry rather than a live probe: the daily
/// aggregation discards raw points, so there is nothing left to derive
/// afterwards (see `biometrics_tables.dart`).
///
/// ## What was wrong with the previous version
///
/// It held five plain fields, and `_load()` resolved four sequential awaits into
/// **one** `setState`. Only one of those awaits was time-bounded. So a hung or
/// failing platform probe threw away the database rows too — and the rows arrive
/// in about a millisecond.
///
/// Measured, not inferred: with a real source row in the DAO, the old screen
/// rendered zero switches and the words "Nothing connected yet" after ten
/// seconds of pumped time. The list has therefore never been laid out by the
/// responsive or build-cost harnesses either; that budget is an empty-state
/// number.
///
/// [ConnectedDevicesController] fixes the cause by emitting twice — rows, then
/// probes — and this screen just renders what it is given.
class ConnectedDevicesScreen extends StatefulWidget {
  /// Injected only by tests, which have no platform to probe. When null the
  /// screen owns its controller and disposes it; when supplied, the caller
  /// keeps that responsibility.
  @visibleForTesting
  final ConnectedDevicesController? controller;

  const ConnectedDevicesScreen({super.key, this.controller});

  @override
  State<ConnectedDevicesScreen> createState() => _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState extends State<ConnectedDevicesScreen>
    with WidgetsBindingObserver {
  late final ConnectedDevicesController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ConnectedDevicesController();
    WidgetsBinding.instance.addObserver(this);
    _controller.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the Health Connect settings sheet is the main way any of
    // this changes, so a resume is the one refresh that really matters.
    if (state == AppLifecycleState.resumed) _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);

    return AccentScope(
      feature: FeatureAccent.brand,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Connected devices',
              leading: AppHeader.backButton(context, accent: ext.brand),
            ),
            Expanded(
              child: ValueListenableBuilder<ConnectedDevicesState>(
                valueListenable: _controller,
                builder: (context, state, _) => AsyncSection<List<HealthSource>>(
                  isLoading: state.isLoading,
                  data: state.sources,
                  error: state.error,
                  onRetry: _controller.load,
                  onRefresh: _controller.load,
                  skeleton: const PageSkeleton.list(rows: 3),
                  errorTitle: "Couldn't read your devices",
                  loadingSemanticLabel: 'Looking for connected devices',
                  // The banner slot exists for exactly this: a permission gate
                  // or a self-disable notice has to be able to sit ABOVE a
                  // populated list, not replace it.
                  banner: _banner(context, state),
                  isEmpty: (s) => s.isEmpty,
                  empty: _empty(context, state),
                  builder: (context, sources) =>
                      _list(context, state, sources),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ BANNER

  Widget? _banner(BuildContext context, ConnectedDevicesState state) {
    final notice = state.selfDisabled;
    if (notice == null) return null;

    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    // Two different facts, two different sentences. `checkFailed` exists
    // because `backgroundReadAuthorization()` returns "unknown" when the probe
    // itself throws — telling someone their permission was revoked when it may
    // not have been is a claim they cannot check.
    final (title, message) = switch (notice.reason) {
      SyncDisableReason.permissionRevoked => (
          'Background sync turned itself off',
          'DlyMinder lost permission to read your health data in the '
              'background, so it stopped trying.',
        ),
      SyncDisableReason.checkFailed => (
          'Background sync turned itself off',
          "DlyMinder couldn't confirm it still had background permission, so "
              'it stopped rather than keep waking your phone for nothing.',
        ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.sync_disabled_rounded,
                  size: 20, color: ext.mark(ext.warning)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title,
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('$message ${RelativeTime.since(notice.at)}.',
              style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          // Wrap, not Row. Two intrinsic-width buttons overflowed this card by
          // 66px at a plain 390pt width — before considering Dynamic Type — and
          // a banner that breaks the layout it is trying to explain is worse
          // than the problem it reports.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              AppButton(
                label: 'Turn it back on',
                variant: AppButtonVariant.tonal,
                size: AppButtonSize.sm,
                accent: ext.brand,
                onPressed: () => _controller.setBackgroundSync(true),
              ),
              AppButton(
                label: 'Dismiss',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                accent: ext.brand,
                onPressed: _controller.dismissSelfDisableNotice,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- EMPTY

  Widget _empty(BuildContext context, ConnectedDevicesState state) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.xxl),
      children: [
        Text(_intro(state),
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
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
              // Honest, and specific about what IS working: steps keep counting
              // from the phone's own sensor with no wearable at all.
              Text(
                "No wearable is writing to your phone's health app yet — or "
                'DlyMinder has not read from it since you allowed access. '
                "Your phone's own step sensor is still counting either way.",
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
              ),
            ],
          ),
        ),
        ..._backgroundSection(context, state),
      ],
    );
  }

  // -------------------------------------------------------------------- LIST

  Widget _list(BuildContext context, ConnectedDevicesState state,
      List<HealthSource> sources) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.xxl),
      children: [
        Text(_intro(state),
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        AppListGroup(
          children: [
            for (final s in sources) _sourceRow(context, state, s),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Turning a source off leaves its past data in place and stops it '
          'being used for new days.',
          style: tt.bodySmall?.copyWith(color: ext.textTertiary),
        ),
        ..._backgroundSection(context, state),
      ],
    );
  }

  /// The lead paragraph.
  ///
  /// The old version claimed "anything writing data shows up here
  /// automatically". It does not: only the *winning* source of a *biometric*
  /// type is ever registered, so a second watch that never wins a day is
  /// invisible here, and steps and sleep never register at all. Overclaiming on
  /// a screen whose entire job is provenance is the worst place to do it.
  String _intro(ConnectedDevicesState state) =>
      state.availability == HealthAvailability.available
          ? "Your watch, ring or band connects to your phone's health app, and "
              'DlyMinder reads from there. Sources appear here once DlyMinder '
              'has actually used their data for a day.'
          : "Wearables connect through your phone's health app rather than "
              'through DlyMinder directly.';

  Widget _sourceRow(
      BuildContext context, ConnectedDevicesState state, HealthSource s) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    final metrics = s.contributedMetrics;
    final what = metrics.isNotEmpty
        ? metrics.map(BiometricMetricKey.label).join(' · ')
        : 'No data yet';
    final seen = RelativeTime.lastSeen(s.lastSeenAt);
    final busy = state.pendingIds.contains(s.id);

    void open() => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => HealthSourceDetailScreen(
            controller: _controller,
            sourceId: s.id,
          ),
        ));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // TWO nodes, deliberately — and this is the part that is easy to get
        // backwards. The row has two actions: the text navigates, the switch
        // toggles. `MergeSemantics` around the WHOLE row would collapse them
        // into one node and the detail screen would become unreachable by
        // screen reader. Merging only the tappable half gives one clean "name,
        // what it feeds, last seen" run that navigates, and leaves the switch a
        // sibling that stays independently operable.
        Expanded(
          child: MergeSemantics(
            child: InkWell(
              onTap: open,
              borderRadius: AppRadius.brMd,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Symbols.watch_rounded,
                        size: 22, color: ext.mark(ext.brand)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(s.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.bodyLarge
                                        ?.copyWith(color: ext.textPrimary)),
                              ),
                              if (s.priority > 0) ...[
                                const SizedBox(width: 6),
                                Icon(Symbols.push_pin_rounded,
                                    size: 14, color: ext.mark(ext.brand)),
                              ],
                            ],
                          ),
                          if (s.deviceModel != null &&
                              s.deviceModel != s.displayName)
                            Text(s.deviceModel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmall
                                    ?.copyWith(color: ext.textTertiary)),
                          const SizedBox(height: 2),
                          Text('$what\n$seen',
                              style: tt.bodySmall
                                  ?.copyWith(color: ext.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // A bare Switch announces as "switch, on" and nothing else. Naming it is
        // the fix; the previous version shipped it unnamed.
        Semantics(
          // container: true so this becomes its own node rather than a wrapper
          // the neighbouring row nests inside. Without it the semantics tree
          // came out INVERTED — the switch node as parent, the device's nav run
          // as its child — which reads as "the switch contains the device".
          container: true,
          label: 'Use ${s.displayName} for health data',
          child: AppSwitch(
            value: s.enabled,
            // Only THIS row disables while its own write is in flight.
            onChanged: busy ? null : (v) => _controller.setEnabled(s, v),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }

  // ------------------------------------------------------------- BACKGROUND

  List<Widget> _backgroundSection(
      BuildContext context, ConnectedDevicesState state) {
    // Hidden entirely when the platform cannot do it — a toggle that does
    // nothing is worse than no toggle.
    if (!state.backgroundAvailable) return const [];

    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return [
      const SizedBox(height: AppSpacing.xl),
      SettingsSection(
        title: 'Background sync',
        footer: 'Asks for one more Health Connect permission. Without it your '
            'data still updates every time you open DlyMinder.',
        children: [
          SettingsTile(
            icon: Symbols.sync_rounded,
            title: 'Keep syncing in the background',
            // The old copy said "your steps and sleep stay current". The worker
            // reads steps only, and what it writes is a snapshot the app merges
            // on next open — so "sleep" was wrong and "current" overstated it.
            subtitle: 'Checks your step count periodically so it is already '
                'up to date next time you open DlyMinder.',
            switchValue: state.backgroundEnabled,
            onSwitchChanged: _controller.setBackgroundSync,
            accent: ext.brand,
          ),
        ],
      ),
      // Written by the worker since it was built, read by nobody until now.
      if (state.backgroundEnabled) ...[
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            state.lastRunAt == null
                // Honest: WorkManager's initial delay is fifteen minutes, so
                // "never run" right after enabling is expected, not a fault.
                ? 'Waiting for the first check.'
                : 'Last checked ${RelativeTime.since(state.lastRunAt!)}.',
            style: tt.bodySmall?.copyWith(color: ext.textTertiary),
          ),
        ),
      ],
      // Only while enabled: a stale error on a switched-off feature is noise,
      // and it clears itself on the next successful run anyway.
      if (state.backgroundEnabled && state.lastError != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.sm),
            title: Text('The last check reported a problem',
                style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
            children: [
              // Behind a disclosure on purpose: this is a raw exception string,
              // a diagnostic breadcrumb rather than user copy. On the surface it
              // reads as a crash.
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  state.lastError!,
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }
}
