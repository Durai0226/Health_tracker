import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/widgets/app/app_widgets.dart';
import '../models/reminder_model.dart';
import '../models/reminder_recurrence.dart';
import '../models/reminder_rule_edit.dart';

/// A repeat Smart Add wrote — "every 3 days", "every other Tuesday" — in words,
/// with the one change that is always safe: how far apart.
///
/// The form's dropdown cannot express these, so it used to read "Does not repeat"
/// beside a reminder that repeats, and the only way to change one was to throw it
/// away. Everything else the rule carries — which weekday, a count, an end date —
/// is kept as it was; "Use a standard repeat instead" is the way out of it.
class ReminderRuleEditor extends StatelessWidget {
  const ReminderRuleEditor({
    super.key,
    required this.rule,
    required this.onChanged,
    required this.onUseStandard,
    required this.accent,
  });

  /// The stored `RRULE:` string.
  final String rule;

  /// The same rule, with a new gap between occurrences.
  final ValueChanged<String> onChanged;

  /// Let go of the rule, for the form's own repeat choices.
  final VoidCallback onUseStandard;

  final AccentSwatch accent;

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final read = ReminderRuleEdit.read(rule);

    void step(int by) {
      final next = ReminderRuleEdit.withInterval(rule, read!.interval + by);
      if (next != null) onChanged(next);
    }

    // What the rule says beyond how far apart — "every other week on Tuesday" —
    // when it says anything; a plain "every 3 days" has nothing to add.
    final detail = read != null && ReminderRuleEdit.isPlain(rule)
        ? const SizedBox.shrink()
        : FutureBuilder<String>(
      future: ReminderRecurrence.parse(rule, fallback: RepeatType.none).describe(),
      builder: (context, snapshot) {
        final text = snapshot.data;
        if (text == null || text.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(text,
              style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Row(children: [
            Icon(Symbols.repeat_rounded, color: ext.mark(accent)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (read != null)
                    Text(ReminderRuleEdit.say(read.frequency, read.interval),
                        style: tt.bodyLarge?.copyWith(color: ext.textPrimary))
                  else
                    Text('Repeats on its own schedule',
                        style: tt.bodyLarge?.copyWith(color: ext.textPrimary)),
                  detail,
                ],
              ),
            ),
            if (read != null) ...[
              IconButton(
                tooltip: 'More often',
                onPressed: read.interval > 1 ? () => step(-1) : null,
                icon: const Icon(Symbols.remove_rounded),
              ),
              IconButton(
                tooltip: 'Less often',
                onPressed: read.interval < ReminderRuleEdit.maxInterval
                    ? () => step(1)
                    : null,
                icon: const Icon(Symbols.add_rounded),
              ),
            ],
          ]),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onUseStandard,
            child: const Text('Use a standard repeat instead'),
          ),
        ),
      ],
    );
  }
}
