/// One short report for the morning: last night against the person's usual, the
/// sleep debt, the overnight body check, and at most ONE suggestion.
///
/// Pure Dart. It puts together figures other parts of the app already work out
/// and adds none of its own. No score, and no verdict on the night: it says what
/// was and what would help. The suggestion is a single line, in priority order,
/// and there is none when nothing calls for one.
library;

import 'overnight_body.dart';
import 'sleep_debt.dart';

class MorningReport {
  const MorningReport({required this.lines, this.suggestion});

  /// The report, a line each, in the order they are shown.
  final List<String> lines;

  /// The one thing worth doing about it, or null.
  final String? suggestion;

  /// Earlier nights needed before "your usual" is said.
  static const int minUsualNights = 5;

  /// Within this many minutes of the usual is "about your usual".
  static const int aboutUsualMinutes = 15;

  /// A night this much under the usual is a short one, worth a suggestion.
  static const int shortNightMinutes = 45;

  /// Debt below this is not worth a line.
  static const int minDebtMinutes = 30;

  /// Debt from this on, with a catch-up that is realistic, is worth a suggestion.
  static const int suggestDebtMinutes = 60;

  /// Signals outside their range, of at least [minBodyChecked], that call for a
  /// lighter day.
  static const int lightDayOutside = 3;
  static const int minBodyChecked = 4;

  /// [earlierNights] are the minutes asleep on the nights before last night.
  /// Null when there is no night to report on.
  static MorningReport? build({
    required int lastNightMinutes,
    required List<int> earlierNights,
    SleepDebtResult? debt,
    OvernightBodyCheck? body,
  }) {
    if (lastNightMinutes <= 0) return null;

    int? usual;
    if (earlierNights.length >= minUsualNights) {
      usual = (earlierNights.reduce((a, b) => a + b) / earlierNights.length).round();
    }

    final lines = <String>[_night(lastNightMinutes, usual)];

    final hasDebt = debt != null &&
        debt.nights >= SleepDebt.minNights &&
        debt.debtMinutes >= minDebtMinutes;
    if (hasDebt) lines.add(debt.behindLine);
    if (body != null) lines.add(body.headline);

    return MorningReport(
      lines: lines,
      suggestion: _suggestion(
        last: lastNightMinutes,
        usual: usual,
        debt: hasDebt ? debt : null,
        body: body,
      ),
    );
  }

  static String _night(int last, int? usual) {
    final slept = 'You slept ${_hm(last)}';
    if (usual == null) return '$slept.';
    final diff = last - usual;
    if (diff.abs() <= aboutUsualMinutes) {
      return '$slept, about your usual ${_hm(usual)}.';
    }
    return '$slept — ${_dur(diff.abs())} ${diff < 0 ? 'under' : 'over'} your '
        'usual ${_hm(usual)}.';
  }

  static String? _suggestion({
    required int last,
    required int? usual,
    required SleepDebtResult? debt,
    required OvernightBodyCheck? body,
  }) {
    if (body != null &&
        body.checked >= minBodyChecked &&
        body.outside >= lightDayOutside) {
      return 'Your body signals are off this morning. Go a little lighter today '
          'if you can.';
    }
    final catchUp = debt?.catchUp;
    if (debt != null && catchUp != null && debt.debtMinutes >= suggestDebtMinutes) {
      final span = catchUp.days == 7 ? 'a week' : 'two weeks';
      return 'Try ${catchUp.minutesPerNight} extra minutes of sleep tonight, and '
          'for $span: it clears the debt.';
    }
    if (usual != null && usual - last >= shortNightMinutes) {
      return 'A short night: an earlier one tonight helps most.';
    }
    return null;
  }

  /// "6h 40m".
  static String _hm(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';

  /// "45 min", or "1 h 5 min" from an hour up.
  static String _dur(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }
}
