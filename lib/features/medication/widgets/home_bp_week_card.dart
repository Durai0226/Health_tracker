import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/home_bp_week.dart';
import '../../../core/health/vitals_analyzer.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/app/vitals_theme.dart';

/// The home-BP week, in whichever state it is in: offered, under way, or done.
class HomeBpWeekCard extends StatelessWidget {
  const HomeBpWeekCard({
    super.key,
    required this.accent,
    required this.onStart,
    required this.onStop,
    required this.onCopy,
    required this.onClose,
    this.progress,
  });

  final AccentSwatch accent;

  /// Null when no week is running.
  final HomeBpProgress? progress;

  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    if (p == null) return _offer(context);
    return p.ended ? _result(context, p) : _underway(context, p);
  }

  Widget _header(BuildContext context, String title, {String? trailing}) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(Symbols.calendar_month_rounded, size: 18, color: ext.mark(accent)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(title,
              style: tt.titleSmall?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w700)),
        ),
        if (trailing != null)
          // Flexible: at large text "Day 3 of 7" alone can be wider than the row.
          Flexible(
            child: Text(trailing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(color: ext.textTertiary)),
          ),
      ],
    );
  }

  Widget _offer(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, 'Home BP week'),
          const SizedBox(height: AppSpacing.sm),
          Text(
              'Seven days, a reading morning and evening, two readings a minute '
              'apart. It ends in an average you can show your doctor.',
              style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Start a week',
              leadingIcon: Symbols.play_arrow_rounded,
              accent: accent,
              onPressed: onStart,
            ),
          ),
        ],
      ),
    );
  }

  Widget _underway(BuildContext context, HomeBpProgress p) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final s = p.summary;
    final String now;
    switch (p.due) {
      case HomeBpSlot.morning:
        now = 'Due now: your morning readings.';
      case HomeBpSlot.evening:
        now = 'Due now: your evening readings.';
      case null:
        now = 'Today\'s readings are done.';
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, 'Home BP week', trailing: 'Day ${p.dayNumber} of 7'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [for (final d in p.days) Expanded(child: _dayDots(context, d, p))],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(now,
              style: tt.bodyMedium?.copyWith(
                  color: ext.textPrimary, fontWeight: FontWeight.w600)),
          if (s.average != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
                s.enough
                    ? 'So far: ${s.average} from ${s.sessions} sessions. The '
                        'first day is left out.'
                    : 'So far: ${s.average} from ${s.sessions} '
                        'session${s.sessions == 1 ? '' : 's'}. It becomes a home '
                        'average from ${HomeBpWeek.minSessions} sessions on '
                        '${HomeBpWeek.minDays} days; the first day is left out.',
                style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onStop,
              style: TextButton.styleFrom(
                  foregroundColor: ext.textSecondary,
                  minimumSize: const Size(0, 44)),
              child: const Text('Stop this week'),
            ),
          ),
        ],
      ),
    );
  }

  /// One day: its number over a morning dot and an evening dot.
  Widget _dayDots(BuildContext context, HomeBpDay d, HomeBpProgress p) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final isToday = d.number == p.dayNumber && !p.ended;
    final past = d.number < p.dayNumber || p.ended;

    Widget dot(bool done, bool missed, IconData icon, String label) {
      return Semantics(
        label: 'Day ${d.number} $label: ${done ? 'taken' : missed ? 'missed' : 'to do'}',
        child: ExcludeSemantics(
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? ext.mark(accent) : Colors.transparent,
              border: Border.all(
                  color: done ? ext.mark(accent) : ext.outlineStrong, width: 1.5),
            ),
            child: Icon(
              done ? Symbols.check_rounded : icon,
              size: 14,
              color: done ? ext.surface : (missed ? ext.textTertiary : ext.outlineStrong),
            ),
          ),
        ),
      );
    }

    // A slot is "missed" once its day has gone, or its half of today has.
    final morningGone = past || (isToday && clock.now().hour >= 12);
    final eveningGone = past;
    return Column(
      children: [
        Text('${d.number}',
            style: tt.labelMedium?.copyWith(
                color: isToday ? ext.mark(accent) : ext.textTertiary,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500)),
        dot(d.morningDone, !d.morningDone && morningGone,
            Symbols.wb_sunny_rounded, 'morning'),
        dot(d.eveningDone, !d.eveningDone && eveningGone,
            Symbols.nightlight_rounded, 'evening'),
      ],
    );
  }

  Widget _result(BuildContext context, HomeBpProgress p) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final s = p.summary;
    final cat = s.category;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, 'Your home week'),
          const SizedBox(height: AppSpacing.sm),
          if (s.average == null || !s.enough) ...[
            Text(
                s.average == null
                    ? 'Not enough to average: only the first day, which is left '
                        'out, has readings.'
                    : 'Not quite enough for a home average: ${s.sessions} '
                        'session${s.sessions == 1 ? '' : 's'} on ${s.days} '
                        'day${s.days == 1 ? '' : 's'}, and it takes '
                        '${HomeBpWeek.minSessions} on ${HomeBpWeek.minDays}. '
                        'So far it is ${s.average}.',
                style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(s.average!,
                    style: tt.headlineMedium?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w800)),
                const SizedBox(width: AppSpacing.xs),
                Text('mmHg',
                    style: tt.labelLarge?.copyWith(color: ext.textTertiary)),
              ],
            ),
            if (cat != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(VitalsColors.bpIcon(cat),
                        size: 18, color: VitalsColors.bpBand(ext.isDark, cat)),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text('${VitalsAnalyzer.bpLabel(cat)} range',
                          style: tt.bodyMedium?.copyWith(
                              color: ext.textPrimary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
                'From ${s.sessions} sessions on ${s.days} days; the first day is '
                'left out.'
                '${s.morning != null && s.evening != null ? ' Morning ${s.morning}, evening ${s.evening}.' : ''}',
                style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
              'This describes your readings; it is not a diagnosis. A doctor may '
              'read a home average against slightly lower cut-offs.',
              style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (s.average != null)
                AppButton(
                  label: 'Copy summary',
                  leadingIcon: Symbols.content_copy_rounded,
                  accent: accent,
                  onPressed: onCopy,
                ),
              TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(
                    foregroundColor: ext.textSecondary,
                    minimumSize: const Size(0, 44)),
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the person chooses when they begin: whether to be reminded each
/// morning and evening. Both start ON, as an offer they confirm by pressing
/// Start — nothing is switched on before they do.
class HomeBpWeekStartSheet extends StatefulWidget {
  const HomeBpWeekStartSheet({super.key, required this.accent});

  final AccentSwatch accent;

  static Future<({bool morning, bool evening})?> show(
    BuildContext context, {
    required AccentSwatch accent,
  }) =>
      AppBottomSheet.show<({bool morning, bool evening})>(
        context,
        title: 'Start a home BP week',
        icon: Symbols.calendar_month_rounded,
        accent: accent,
        builder: (_) => HomeBpWeekStartSheet(accent: accent),
      );

  @override
  State<HomeBpWeekStartSheet> createState() => _HomeBpWeekStartSheetState();
}

class _HomeBpWeekStartSheetState extends State<HomeBpWeekStartSheet> {
  bool _morning = true;
  bool _evening = true;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            'For seven days, measure each morning (before breakfast and '
            'medicines) and each evening (before dinner): sit quietly for five '
            'minutes, then take two readings about a minute apart. The first '
            'day is left out and the rest are averaged.',
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        SettingsSection(
          children: [
            SettingsTile(
              icon: Symbols.wb_sunny_rounded,
              title: 'Morning reminder',
              subtitle: '9:00 AM',
              accent: widget.accent,
              switchValue: _morning,
              onSwitchChanged: (v) => setState(() => _morning = v),
            ),
            SettingsTile(
              icon: Symbols.nightlight_rounded,
              title: 'Evening reminder',
              subtitle: '7:00 PM',
              accent: widget.accent,
              switchValue: _evening,
              onSwitchChanged: (v) => setState(() => _evening = v),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Start',
          leadingIcon: Symbols.play_arrow_rounded,
          accent: widget.accent,
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: () =>
              Navigator.pop(context, (morning: _morning, evening: _evening)),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
