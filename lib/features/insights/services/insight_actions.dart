import 'package:flutter/material.dart';

import '../../../core/health/insight.dart';
import '../../reminders/models/reminder_model.dart';
import '../../reminders/screens/add_reminder_screen.dart';

/// What an insight's action button does, or null when it declares none.
///
/// `InsightCard` renders its action button only when `onAction` is non-null, so
/// an `actionLabel` with nothing wired to it is a call to action the user can
/// never see. `focus_besthour` shipped exactly that way — on the one insight
/// designed to create a reminder.
///
/// This lives in a service rather than at the render site for two reasons. It
/// makes [hourFromMetric] testable — it parses formatted output and had never
/// been tested despite that. And it lets the completeness guard assert against
/// [handled], a real Dart value, instead of grepping a screen file for a source
/// string: that grep broke the moment the screen was rebuilt, and a comment
/// containing the right text could satisfy it.
class InsightActions {
  const InsightActions._();

  /// Every insight id this app knows how to act on.
  ///
  /// `insight_action_wiring_test.dart` asserts that every insight declaring an
  /// `actionLabel` appears here, so a second one cannot ship dead the way the
  /// first did. Adding an id here without a `case` below is caught too — the
  /// switch is exhaustive over this set by test, not by the compiler.
  static const Set<String> handled = {'focus_besthour'};

  /// The callback for [insight], or null when it declares no action or the id
  /// is not one we handle.
  static VoidCallback? of(BuildContext context, Insight insight) {
    if (insight.actionLabel == null) return null;
    switch (insight.id) {
      case 'focus_besthour':
        // Pre-fill a reminder at the hour the user actually focuses best, and
        // let them confirm it. Deliberately a push to the normal add screen and
        // not a silent write: the whole adaptive story here is "suggest, never
        // impose".
        return () {
          final hour = hourFromMetric(insight.metric);
          if (hour == null) return;
          final now = DateTime.now();
          var at = DateTime(now.year, now.month, now.day, hour);
          if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AddReminderScreen(
                initialTitle: 'Deep work',
                initialTime: at,
                initialRepeat: RepeatType.weekdays,
              ),
            ),
          );
        };
      default:
        return null;
    }
  }

  /// Recover the hour from `FocusInsights.hourLabel` output ("9 AM", "2 PM").
  ///
  /// Public so it can be tested directly. It parses a string the engine
  /// formatted from an int it already had, which is fragile by construction —
  /// if `hourLabel` ever renders an hour without a digit, the action silently
  /// no-ops rather than failing. A test pins both this parser and the engine's
  /// output format.
  static int? hourFromMetric(String? metric) {
    if (metric == null) return null;
    final m = RegExp(r'(\d{1,2})').firstMatch(metric);
    if (m == null) return null;
    var hour = int.parse(m.group(1)!);
    final upper = metric.toUpperCase();
    if (upper.contains('PM') && hour < 12) hour += 12;
    if (upper.contains('AM') && hour == 12) hour = 0;
    return (hour >= 0 && hour <= 23) ? hour : null;
  }
}
