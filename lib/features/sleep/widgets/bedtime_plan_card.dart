import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/health/bedtime_plan.dart';
import '../../../core/widgets/app/app_widgets.dart';

/// "Aim for 10:40 PM" with its working: the time in bed, the sleep it is for,
/// any catch-up for the sleep owed and the time usually spent awake. A soft
/// target, never a rule.
///
/// With the wind-down reminder on it says when that rings, and offers — never
/// silently — to have it follow the plan from here on.
class BedtimePlanCard extends StatelessWidget {
  const BedtimePlanCard({
    super.key,
    required this.plan,
    required this.windDownLeadMinutes,
    required this.reminderEnabled,
    required this.followPlan,
    this.fixedReminderMinuteOfDay,
    this.onFollowPlan,
  });

  final BedtimePlan plan;
  final int windDownLeadMinutes;
  final bool reminderEnabled;
  final bool followPlan;

  /// Where the reminder sits when it does not follow the plan.
  final int? fixedReminderMinuteOfDay;

  /// Have the reminder follow the plan. Offered only when it would move.
  final VoidCallback? onFollowPlan;

  /// The reminder has to be at least this far from the plan's wind-down time
  /// for following it to be worth offering.
  static const int worthMovingMinutes = 5;

  static String _time(BuildContext context, int minuteOfDay) =>
      TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60).format(context);

  /// "8 h 20 m in bed: your 7 h 45 m of sleep, 20 m of catch-up and about 15 m
  /// awake in bed."
  static String detail(BedtimePlan p) {
    final parts = <String>[
      'your ${BedtimePlans.duration(p.needMinutes)} of sleep',
      if (p.catchUpMinutes > 0) '${BedtimePlans.duration(p.catchUpMinutes)} of catch-up',
      'about ${BedtimePlans.duration(p.awakeMinutes)} awake in bed',
    ];
    final working = parts.length == 1
        ? parts.single
        : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
    return '${BedtimePlans.duration(p.inBedMinutes)} in bed: $working.';
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final windDown = plan.windDownMinuteOfDay(windDownLeadMinutes);
    final fixed = fixedReminderMinuteOfDay;
    final offer = reminderEnabled &&
        !followPlan &&
        onFollowPlan != null &&
        fixed != null &&
        _apart(fixed, windDown) >= worthMovingMinutes;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ext.sleep.container,
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(Symbols.nights_stay_rounded,
                    size: 22, color: ext.sleep.onContainer),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppEyebrow("TONIGHT'S BEDTIME"),
                    const SizedBox(height: 2),
                    Text('Aim for ${_time(context, plan.bedMinuteOfDay)}',
                        style: tt.titleLarge),
                    const SizedBox(height: 2),
                    Text(detail(plan),
                        style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (reminderEnabled) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              followPlan
                  ? 'Your wind-down reminder follows this plan: '
                      '${_time(context, windDown)} tonight.'
                  : 'Your wind-down reminder is at ${_time(context, fixed ?? windDown)}.',
              style: tt.bodySmall?.copyWith(color: ext.textTertiary),
            ),
          ],
          if (offer) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onFollowPlan,
                child: Text('Move it to ${_time(context, windDown)} and keep it there'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The shorter way round the clock between two minutes of the day.
  static int _apart(int a, int b) {
    final d = (a - b).abs() % 1440;
    return d > 720 ? 1440 - d : d;
  }
}
