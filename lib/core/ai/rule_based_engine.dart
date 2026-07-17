import 'ai_types.dart';
import 'hydration_pacer.dart';

/// Pure-Dart, deterministic AI engine. Zero cost, zero infra, offline, private —
/// runs on every device and scales to unlimited users for free. It is the
/// universal default and the guaranteed fallback behind [AiAssistant].
///
/// Deterministic-by-input (no randomness) so it's fully unit-testable.
class RuleBasedEngine {
  const RuleBasedEngine();

  // ---------------------------------------------------------------------------
  // Reminders — natural-language parsing
  // ---------------------------------------------------------------------------
  ParsedReminder parseReminder(String input) {
    final text = input.trim();
    final lower = text.toLowerCase();
    final now = DateTime.now();

    var repeat = _repeat(lower);
    final priority = _priority(lower);
    final category = _category(lower);
    List<int>? customDays;
    final durationMinutes = _parseDuration(lower);

    // Relative "in N minutes/hours/days/weeks/months/years" takes precedence.
    final rel = RegExp(
            r'\bin\s+(\d+)\s*(hours?|hrs?|minutes?|mins?|days?|weeks?|wks?|months?|years?)\b')
        .firstMatch(lower);
    if (rel != null) {
      final n = int.parse(rel.group(1)!);
      final unit = rel.group(2)!;
      DateTime when;
      if (unit.startsWith('h')) {
        when = now.add(Duration(hours: n));
      } else if (unit.startsWith('mi')) {
        when = now.add(Duration(minutes: n));
      } else if (unit.startsWith('d')) {
        when = now.add(Duration(days: n));
      } else if (unit.startsWith('w')) {
        when = now.add(Duration(days: 7 * n));
      } else if (unit.startsWith('mo')) {
        // Calendar month math (not a fixed 30 days).
        when = DateTime(now.year, now.month + n, now.day, now.hour, now.minute);
      } else {
        // years
        when = DateTime(now.year + n, now.month, now.day, now.hour, now.minute);
      }
      return ParsedReminder(
        title: _cleanTitle(text),
        time: when,
        repeat: repeat,
        priority: priority,
        categoryHint: category,
        durationMinutes: durationMinutes,
      );
    }

    // "next week" / "next month" (no explicit "in N").
    if (RegExp(r'\bnext week\b').hasMatch(lower)) {
      final when = DateTime(now.year, now.month, now.day, 9, 0)
          .add(const Duration(days: 7));
      return ParsedReminder(
        title: _cleanTitle(text),
        time: when,
        repeat: repeat,
        priority: priority,
        categoryHint: category,
        durationMinutes: durationMinutes,
      );
    }
    if (RegExp(r'\bnext month\b').hasMatch(lower)) {
      final when = DateTime(now.year, now.month + 1, now.day, 9, 0);
      return ParsedReminder(
        title: _cleanTitle(text),
        time: when,
        repeat: repeat,
        priority: priority,
        categoryHint: category,
        durationMinutes: durationMinutes,
      );
    }

    // Time of day.
    int? hour;
    int minute = 0;
    final at = RegExp(r'\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b')
            .firstMatch(lower) ??
        RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b').firstMatch(lower);
    if (at != null) {
      hour = int.parse(at.group(1)!);
      minute = at.group(2) != null ? int.parse(at.group(2)!) : 0;
      if (minute > 59) minute = 0; // reject typos like "8:99" instead of shifting
      final ap = at.group(3);
      if (ap == 'pm' && hour < 12) hour += 12;
      if (ap == 'am' && hour == 12) hour = 0;
      // Bare hour with no am/pm: 1–6 almost always means the afternoon/evening
      // (nobody sets a 3-o'clock reminder for 3 AM), so bias those to PM.
      if (ap == null && hour >= 1 && hour <= 6) hour += 12;
      if (hour > 23) hour = null; // guard nonsense
    } else if (lower.contains('morning')) {
      hour = 8;
    } else if (lower.contains('afternoon')) {
      hour = 14;
    } else if (lower.contains('evening')) {
      hour = 19;
    } else if (lower.contains('tonight') || lower.contains('night')) {
      hour = 21;
    } else if (lower.contains('noon')) {
      hour = 12;
    } else if (lower.contains('midnight')) {
      hour = 0;
    }

    // Date.
    DateTime date = DateTime(now.year, now.month, now.day);
    final explicitToday = lower.contains('today') || lower.contains('tonight');
    bool weekdayNamed = false;
    if (lower.contains('tomorrow')) {
      date = date.add(const Duration(days: 1));
    } else if (!explicitToday) {
      final wdays = _weekdaysAll(lower);
      if (wdays.length == 1) {
        date = _nextWeekday(date, wdays.first);
        weekdayNamed = true;
      } else if (wdays.length > 1) {
        // Multiple named days ("mon and thu") describe a multi-day schedule —
        // never collapse them to a single weekly reminder (drops the others).
        final set = wdays.toSet();
        if (set.length == 5 && set.containsAll(const {1, 2, 3, 4, 5})) {
          repeat = 'weekdays';
        } else if (set.length == 2 && set.containsAll(const {6, 7})) {
          repeat = 'weekends';
        } else {
          repeat = 'custom';
          customDays = wdays;
        }
        // Anchor at the nearest upcoming named day.
        date = wdays
            .map((d) => _nextWeekday(date, d))
            .reduce((a, b) => a.isBefore(b) ? a : b);
      }
    }
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    DateTime when;
    if (hour != null) {
      when = DateTime(date.year, date.month, date.day, hour, minute);
      // If the chosen instant is already past for a one-off, roll forward so we
      // never schedule a dead (past) reminder: a named weekday jumps a full
      // week; every other case (incl. an explicit "today"/"tonight" whose time
      // already passed) rolls to the next day at the same time. weekdayNamed is
      // only ever true when !explicitToday, so this covers all cases correctly.
      if (when.isBefore(now) && repeat == 'none') {
        when = when.add(Duration(days: weekdayNamed ? 7 : 1));
      }
    } else if (isToday) {
      // No time given, and the date is today → next hour (guard 23→next day).
      final h = now.hour + 1;
      when = DateTime(now.year, now.month, now.day).add(Duration(hours: h));
    } else {
      // No time given on a future date → sensible default of 9:00 AM (keeps the
      // parsed date instead of collapsing back to today).
      when = DateTime(date.year, date.month, date.day, 9, 0);
    }

    return ParsedReminder(
      title: _cleanTitle(text),
      time: when,
      repeat: repeat,
      priority: priority,
      categoryHint: category,
      customDays: customDays,
      durationMinutes: durationMinutes,
    );
  }

  /// Parse an explicit session/event length ("for 30 minutes", "25 min",
  /// "for 1 hour", "1h30m") → minutes, or null. Hours/minutes only (a duration,
  /// not a multi-day bound).
  int? _parseDuration(String lower) {
    // "for 1 hour 30 minutes" / "for 2 hours". Word units only (no bare h/m) so
    // "for 5 meetings" can't be misread as a duration.
    final forHM = RegExp(
            r'\bfor\s+(\d+)\s*(?:hours?|hrs?)(?:\s+(\d+)\s*(?:minutes?|mins?))?\b')
        .firstMatch(lower);
    if (forHM != null) {
      final h = int.parse(forHM.group(1)!);
      final m = int.tryParse(forHM.group(2) ?? '') ?? 0;
      final total = h * 60 + m;
      if (total > 0) return total;
    }
    // "for 30 minutes" / "for 90 min"
    final forMin =
        RegExp(r'\bfor\s+(\d+)\s*(?:minutes?|mins?)\b').firstMatch(lower);
    if (forMin != null) return int.parse(forMin.group(1)!);
    // "25 min session" / "45-minute focus" / "1 hour timer"
    final sess = RegExp(
            r'\b(\d+)\s*(hours?|hrs?|minutes?|mins?)[\s-]*(session|focus|timer|block)\b')
        .firstMatch(lower);
    if (sess != null) {
      final n = int.parse(sess.group(1)!);
      return sess.group(2)!.startsWith('h') ? n * 60 : n;
    }
    return null;
  }

  String _repeat(String lower) {
    if (RegExp(r'\bweekday').hasMatch(lower)) return 'weekdays';
    if (RegExp(r'\bweekend').hasMatch(lower)) return 'weekends';
    if (RegExp(r'\b(daily|everyday|every day|each day|every morning|every afternoon|every evening|every night)\b')
        .hasMatch(lower)) {
      return 'daily';
    }
    if (RegExp(r'\b(weekly|every week)\b').hasMatch(lower)) return 'weekly';
    // "every monday" / "on mondays"
    if (RegExp(r'\b(every|on)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?\b')
        .hasMatch(lower)) {
      return 'weekly';
    }
    return 'none';
  }

  String _priority(String lower) {
    if (RegExp(r'\b(urgent|important|asap|critical|high priority)\b')
        .hasMatch(lower)) return 'high';
    if (RegExp(r'\b(low priority|whenever|sometime|no rush)\b').hasMatch(lower)) {
      return 'low';
    }
    return 'medium';
  }

  String? _category(String lower) {
    if (RegExp(r'\b(medicine|medication|pill|pills|dose|tablet|meds?|vitamin|insulin)\b')
        .hasMatch(lower)) return 'Health';
    if (RegExp(r'\b(gym|workout|exercise|run|walk|yoga|water|drink)\b')
        .hasMatch(lower)) return 'Health';
    if (RegExp(r'\b(work|meeting|email|report|deadline|project|client)\b')
        .hasMatch(lower)) return 'Work';
    if (RegExp(r'\b(call|birthday|family|friend|mom|dad|anniversary)\b')
        .hasMatch(lower)) return 'Personal';
    return null;
  }

  /// All distinct named weekdays in [lower], sorted (1=Mon … 7=Sun).
  List<int> _weekdaysAll(String lower) {
    const days = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    final found = <int>{};
    for (final e in days.entries) {
      if (lower.contains(e.key)) found.add(e.value);
    }
    return found.toList()..sort();
  }

  DateTime _nextWeekday(DateTime from, int weekday) {
    var d = from;
    // 0..6 days ahead; if today matches, keep today.
    while (d.weekday != weekday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  String _cleanTitle(String text) {
    var t = ' $text ';
    final patterns = <RegExp>[
      RegExp(r'\bremind me to\b', caseSensitive: false),
      RegExp(r'\bremind me\b', caseSensitive: false),
      RegExp(r'\bset a reminder to\b', caseSensitive: false),
      RegExp(r'\breminder to\b', caseSensitive: false),
      RegExp(r'\bat\s+\d{1,2}(?::\d{2})?\s*(am|pm)?\b', caseSensitive: false),
      RegExp(r'\b\d{1,2}(?::\d{2})?\s*(am|pm)\b', caseSensitive: false),
      RegExp(
          r'\bevery\s+(morning|afternoon|evening|night|day|week|weekday|weekend|monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?\b',
          caseSensitive: false),
      RegExp(r'\bon\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?\b',
          caseSensitive: false),
      // Any remaining bare weekday, swallowing a leading "and"/"&" connector so
      // "monday and thursday" doesn't leave "and thursday" in the title.
      RegExp(
          r'\b(and\s+|&\s*)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?\b',
          caseSensitive: false),
      RegExp(r'\b(weekdays?|weekends?)\b', caseSensitive: false),
      RegExp(r'\b(daily|everyday|every day|each day|weekly)\b',
          caseSensitive: false),
      RegExp(r'\b(today|tomorrow|tonight)\b', caseSensitive: false),
      RegExp(
          r'\bin\s+\d+\s*(hours?|hrs?|minutes?|mins?|days?|weeks?|wks?|months?|years?)\b',
          caseSensitive: false),
      // Duration phrase ("for 1 hour 30 min", "for 30 minutes"). Word units +
      // required digit so a plain "for <word>" title isn't stripped.
      RegExp(r'\bfor\s+\d+\s*(hours?|hrs?)(\s+\d+\s*(minutes?|mins?))?\b',
          caseSensitive: false),
      RegExp(r'\bfor\s+\d+\s*(minutes?|mins?)\b', caseSensitive: false),
      // "N min session/focus/timer" duration.
      RegExp(r'\b\d+\s*(hours?|hrs?|minutes?|mins?)[\s-]*(session|focus|timer|block)\b',
          caseSensitive: false),
      RegExp(r'\b(this|next)\s+(morning|afternoon|evening|week|month)\b',
          caseSensitive: false),
      RegExp(r'\b(urgent|important|asap|critical|high priority|low priority|no rush)\b',
          caseSensitive: false),
      RegExp(r'\b(morning|afternoon|evening|night|noon|midnight)\b',
          caseSensitive: false),
    ];
    for (final p in patterns) {
      t = t.replaceAll(p, ' ');
    }
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) t = text.trim();
    return _capitalize(t);
  }

  // ---------------------------------------------------------------------------
  // Medicine — natural-language parsing
  // ---------------------------------------------------------------------------
  Map<String, dynamic> parseMedicine(String input) {
    final lower = input.toLowerCase();
    final res = <String, dynamic>{};

    final dose = RegExp(r'(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml|iu|units?)')
        .firstMatch(lower);
    if (dose != null) {
      res['dosageAmount'] = double.tryParse(dose.group(1)!);
      res['dosageUnit'] = dose.group(2);
    }

    for (final f in const [
      'tablet',
      'capsule',
      'liquid',
      'syrup',
      'injection',
      'drops',
      'cream',
      'inhaler',
      'patch'
    ]) {
      if (lower.contains(f)) {
        res['form'] = f;
        break;
      }
    }

    String? freq;
    if (RegExp(r'\b(once|1x|once a day|once daily)\b').hasMatch(lower)) {
      freq = 'once daily';
    } else if (RegExp(r'\b(twice|2x|two times)\b').hasMatch(lower)) {
      freq = 'twice daily';
    } else if (RegExp(r'\b(thrice|3x|three times)\b').hasMatch(lower)) {
      freq = 'thrice daily';
    } else if (RegExp(r'\b(four times|4x)\b').hasMatch(lower)) {
      freq = 'four times daily';
    } else if (RegExp(r'\b(as needed|prn|when needed)\b').hasMatch(lower)) {
      freq = 'asNeeded';
    } else if (RegExp(r'every\s+(\d+)\s*hours?').hasMatch(lower)) {
      freq = 'everyXHours';
      res['intervalHours'] =
          int.tryParse(RegExp(r'every\s+(\d+)\s*hours?').firstMatch(lower)!.group(1)!);
    } else if (lower.contains('daily') || lower.contains('every day')) {
      freq = 'once daily';
    }
    if (freq != null) res['frequency'] = freq;

    var name = input;
    name = name.replaceAll(
        RegExp(r'\d+(?:\.\d+)?\s*(mg|mcg|g|ml|iu|units?)', caseSensitive: false),
        ' ');
    name = name.replaceAll(
        RegExp(
            r'\b(once|twice|thrice|four times|two times|three times|a day|per day|daily|every day|as needed|prn|when needed|tablet|capsule|liquid|syrup|injection|drops|cream|inhaler|patch|take|of)\b',
            caseSensitive: false),
        ' ');
    name = name.replaceAll(RegExp(r'every\s+\d+\s*hours?', caseSensitive: false), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name.isNotEmpty) res['name'] = _capitalize(name);
    return res;
  }

  // ---------------------------------------------------------------------------
  // Tips / insights — templated from real data (deterministic by state)
  // ---------------------------------------------------------------------------
  String hydrationTip({
    required int intakeMl,
    required int goalMl,
    required int streakDays,
    required int hour,
  }) {
    final remaining = (goalMl - intakeMl).clamp(0, goalMl);
    final pct = goalMl > 0 ? (intakeMl / goalMl * 100).round() : 0;
    final streak = streakDays > 0 ? ' Your $streakDays-day streak is looking great!' : '';
    if (intakeMl >= goalMl && goalMl > 0) {
      return '🎉 Goal reached — ${intakeMl}ml today! Keep sipping to stay ahead.$streak';
    }

    // Pace-aware nudge: compare intake to where you'd be if on track for THIS
    // point in the day, not just the daily total. (mid-hour estimate for time.)
    final pace = HydrationPacer.compute(
      intakeMl: intakeMl,
      goalMl: goalMl,
      nowMinutes: hour * 60 + 30,
    );

    if (hour < 10) {
      return 'Good morning! A glass now is a strong start toward your ${goalMl}ml goal.$streak';
    }
    if (pace.behind) {
      final sip = pace.suggestedSipMl > 0 ? pace.suggestedSipMl : 250;
      return 'You\'re about ${pace.deficitMl}ml behind pace — a ${sip}ml drink now gets you back on track ($intakeMl of ${goalMl}ml).$streak';
    }
    if (hour >= 20) {
      return 'You\'re at $pct% ($intakeMl of ${goalMl}ml). A last glass before bed tops you off.$streak';
    }
    if (pace.ahead) {
      return 'Ahead of pace — $pct% of your goal already. Nice work, keep it steady.$streak';
    }
    return 'On pace — $pct% of your goal. Just ${remaining}ml to go.$streak';
  }

  String focusCoach({
    required int todayMinutes,
    required int streakDays,
    required int totalSessions,
  }) {
    if (todayMinutes == 0) {
      return streakDays > 0
          ? 'Keep your $streakDays-day streak alive — a single 25-minute session today does it.'
          : 'Start small: one focused 25-minute session builds momentum.';
    }
    if (todayMinutes < 25) {
      return 'Good start — ${todayMinutes}m in. One more short session compounds your focus.';
    }
    return 'Strong work: ${todayMinutes}m focused today${streakDays > 0 ? ', $streakDays-day streak' : ''}. Take a short break, then one more round.';
  }

  String dailyBriefing({
    required int medsTaken,
    required int medsTotal,
    required int waterPct,
    required int focusMinutes,
    required int remindersLeft,
    required int hour,
  }) {
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final parts = <String>[];
    if (medsTotal > 0) parts.add('meds $medsTaken/$medsTotal');
    parts.add('water $waterPct%');
    if (focusMinutes > 0) parts.add('focus ${focusMinutes}m');
    if (remindersLeft > 0) {
      parts.add('$remindersLeft reminder${remindersLeft == 1 ? '' : 's'} left');
    }
    return '$greeting! Today so far: ${parts.join(' · ')}. You\'ve got this.';
  }

  String explainInteractions(List<String> descriptions) {
    if (descriptions.isEmpty) {
      return 'No notable interactions were detected in your list.';
    }
    final bullets = descriptions.map((d) => '- $d').join('\n');
    return 'Here\'s what to keep in mind:\n$bullets\n\nAlways confirm with your pharmacist or doctor.';
  }

  String medicineAnswer({
    required String name,
    String? dose,
    required String question,
    String? instructions,
  }) {
    final q = question.toLowerCase();
    final base = instructions != null && instructions.trim().isNotEmpty
        ? ' Your saved note: "$instructions".'
        : '';
    if (RegExp(r'\b(food|eat|meal|empty stomach)\b').hasMatch(q)) {
      return 'Whether to take $name with food depends on the specific medicine — follow the label or your pharmacist\'s guidance.$base';
    }
    if (RegExp(r'\b(miss|missed|forgot|skip)\b').hasMatch(q)) {
      return 'If you miss a dose of $name, take it when you remember — unless it\'s almost time for the next dose, in which case skip it. Never double up.$base';
    }
    if (RegExp(r'\b(side effect|side-effect|reaction)\b').hasMatch(q)) {
      return 'Side effects vary by person. Check the leaflet and report anything unusual or severe to your doctor promptly.$base';
    }
    if (RegExp(r'\b(what|for|purpose|used)\b').hasMatch(q)) {
      return '$name${dose != null && dose.isNotEmpty ? ' ($dose)' : ''} should be used as prescribed.$base For what it treats and how, check the leaflet or ask your pharmacist.';
    }
    return 'For questions about $name, the most reliable source is your pharmacist or doctor.$base';
  }

  int suggestWaterGoal({
    double? weightKg,
    String? activity,
    String? climate,
  }) {
    // ~33 ml per kg baseline, sensible default without weight.
    double goal = weightKg != null && weightKg > 0 ? weightKg * 33 : 2500;
    final a = (activity ?? '').toLowerCase();
    if (a.contains('high') || a.contains('active') || a.contains('athlete')) {
      goal += 500;
    } else if (a.contains('low') || a.contains('sedentary')) {
      goal -= 200;
    }
    final c = (climate ?? '').toLowerCase();
    if (c.contains('hot') || c.contains('humid') || c.contains('warm')) {
      goal += 400;
    } else if (c.contains('cold')) {
      goal -= 100;
    }
    return goal.round().clamp(1500, 4000);
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
