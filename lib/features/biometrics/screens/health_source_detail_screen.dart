import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/date_formats.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../models/biometric_metric.dart';
import '../models/health_source.dart';
import '../services/connected_devices_controller.dart';

/// One contributing app or wearable, in full.
///
/// A pushed screen rather than a bottom sheet. Not because a sheet could not be
/// tested — that argument was checked and is false; the repo's harnesses are
/// hand-maintained maps of widget builders and already register a non-route
/// surface. It is a screen because the pin control needs room for its two
/// honesty caveats, and because a stable route is the ordinary way to reach
/// something you might want to come back to.
class HealthSourceDetailScreen extends StatelessWidget {
  final ConnectedDevicesController controller;
  final String sourceId;

  const HealthSourceDetailScreen({
    super.key,
    required this.controller,
    required this.sourceId,
  });

  @override
  Widget build(BuildContext context) {

    return AccentScope(
      feature: FeatureAccent.brand,
      child: AppScaffold(
        body: ValueListenableBuilder<ConnectedDevicesState>(
          valueListenable: controller,
          builder: (context, state, _) {
            // Read the row back out of the controller every build rather than
            // capturing it: toggling from here must be reflected here, and the
            // list screen behind must stay in step without a manual refresh.
            final source = state.sources
                ?.cast<HealthSource?>()
                .firstWhere((s) => s!.id == sourceId, orElse: () => null);

            return Column(
              children: [
                AppHeader(
                  title: source?.displayName ?? 'Device',
                  leading: AppHeader.backButton(context),
                ),
                Expanded(
                  child: source == null
                      ? const EmptyState(
                          icon: Symbols.watch_off_rounded,
                          title: 'This source is gone',
                          message:
                              'It is no longer in the registry on this device.',
                        )
                      : _body(context, state, source),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(
      BuildContext context, ConnectedDevicesState state, HealthSource s) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final busy = state.pendingIds.contains(s.id);
    final metrics = s.contributedMetrics;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.xxl),
      children: [
        if (s.deviceModel != null && s.deviceModel != s.displayName) ...[
          Text(s.deviceModel!,
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
          const SizedBox(height: AppSpacing.md),
        ],

        // ---- What it actually contributes -------------------------------
        SectionHeader(title: 'What it contributes', accent: ext.brand),
        const SizedBox(height: AppSpacing.sm),
        if (metrics.isEmpty)
          AppCard(
            child: Text(
              'Nothing yet. This source is in the registry because it has '
              'written to your health app, but none of it is data DlyMinder '
              'reads.',
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
            ),
          )
        else
          AppListGroup(
            children: [
              for (final key in metrics)
                AppListTile(
                  icon: Symbols.timeline_rounded,
                  title: BiometricMetricKey.label(key),
                  // Counts belong in a list like this, not in a meter with an
                  // invented denominator.
                  subtitle: _metricSubtitle(s, key),
                  accent: ext.brand,
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.xl),

        // ---- Controls ----------------------------------------------------
        SettingsSection(
          title: 'This source',
          children: [
            SettingsTile(
              icon: Symbols.check_circle_rounded,
              title: 'Use for health data',
              subtitle: s.enabled
                  ? 'Counted when DlyMinder works out each day.'
                  : 'Ignored. Past days it already won are unchanged.',
              switchValue: s.enabled,
              onSwitchChanged:
                  busy ? null : (v) => controller.setEnabled(s, v),
            ),
            SettingsTile(
              icon: Symbols.push_pin_rounded,
              title: 'Prefer this device',
              subtitle: 'When two sources have the same reading for a day, '
                  'use this one.',
              switchValue: s.priority > 0,
              onSwitchChanged: busy ? null : (v) => controller.setPinned(s, v),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Two things the control genuinely does not do. Both are the kind of
        // omission a user only discovers by being surprised later.
        Text(
          'A preference applies to every measurement this source writes, not '
          'to one of them — and like the switch above, to today and future '
          'days. Days already worked out stay as they are.',
          style: tt.bodySmall?.copyWith(color: ext.textTertiary),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ---- Provenance ---------------------------------------------------
        SectionHeader(title: 'History', accent: ext.brand),
        const SizedBox(height: AppSpacing.sm),
        AppListGroup(
          separatorIndent: 0,
          children: [
            _fact(context, 'First seen', DateFormats.dayMonthTime.format(s.firstSeenAt)),
            _fact(context, 'Last seen',
                '${DateFormats.dayMonthTime.format(s.lastSeenAt)} · ${RelativeTime.since(s.lastSeenAt)}'),
          ],
        ),
      ],
    );
  }

  String _metricSubtitle(HealthSource s, String key) {
    final stat = s.metrics[key];
    if (stat == null) return 'No readings';
    final n = stat.points;
    return '$n ${n == 1 ? 'reading' : 'readings'} · '
        'last ${RelativeTime.since(stat.lastSeenAt)}';
  }

  Widget _fact(BuildContext context, String label, String value) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: tt.bodyMedium?.copyWith(color: ext.textPrimary)),
          ),
        ],
      ),
    );
  }
}
