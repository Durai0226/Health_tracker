import 'package:clock/clock.dart';

import 'focus_insights.dart';
import 'focus_readiness.dart';
import 'health_types.dart';
import 'hydration_pacer.dart';
import 'sleep_debt.dart';
import 'step_reminder_plan.dart';

/// Pure-Dart, deterministic AI engine. Zero cost, zero infra, offline, private —
/// runs on every device and scales to unlimited users for free. It is the
/// universal default and the guaranteed fallback behind [AiAssistant].
///
/// Deterministic-by-input (no randomness) so it's fully unit-testable.
class CoachText {
  const CoachText();

  // ---------------------------------------------------------------------------
  // Natural-language logging commands ("log 150/95", "drank 500ml", "took pill")
  // ---------------------------------------------------------------------------
  ParsedCommand parseCommand(String input) {
    final q = input.toLowerCase().trim();

    // Blood pressure: "150/95", "150 over 95", optionally with bp/pressure words.
    final bp = RegExp(r'\b(\d{2,3})\s*(?:/|over)\s*(\d{2,3})\b').firstMatch(q);
    if (bp != null) {
      final sys = int.parse(bp.group(1)!);
      final dia = int.parse(bp.group(2)!);
      if (sys > dia && sys <= 300 && dia >= 20) {
        return ParsedCommand(
            CommandKind.logBloodPressure, {'systolic': sys, 'diastolic': dia});
      }
    }

    // Water: "drank 500ml", "log 500 ml water", "water 500".
    if (RegExp(r'\b(water|drank|drink|hydrate)\b').hasMatch(q)) {
      final byUnit = RegExp(r'\b(\d{2,4})\s*ml\b').firstMatch(q);
      final byWord =
          RegExp(r'\b(?:water|drank|drink|hydrate)\D{0,6}(\d{2,4})\b').firstMatch(q);
      final v = byUnit != null
          ? int.tryParse(byUnit.group(1)!)
          : (byWord != null ? int.tryParse(byWord.group(1)!) : null);
      if (v != null && v >= 10 && v <= 5000) {
        return ParsedCommand(CommandKind.logWater, {'ml': v});
      }
    }

    // Glucose: "sugar 120", "glucose 6.5", "blood sugar 140".
    final glMatch =
        RegExp(r'\b(?:glucose|sugar|bg)\D{0,6}(\d{1,3}(?:\.\d)?)\b').firstMatch(q);
    if (glMatch != null) {
      final raw = double.tryParse(glMatch.group(1)!);
      if (raw != null) {
        // Small values are almost certainly mmol/L → convert to canonical mg/dL.
        final mgdl = raw < 30 ? (raw * 18.0182).round() : raw.round();
        if (mgdl >= 10 && mgdl <= 900) {
          return ParsedCommand(CommandKind.logGlucose, {'mgdl': mgdl});
        }
      }
    }

    // Medicine: "took my pill", "took my meds", "log medicine".
    if (RegExp(r'\b(took|take|taken|log)\b.*\b(pill|meds?|medicine|dose|tablet)\b')
        .hasMatch(q)) {
      return const ParsedCommand(CommandKind.takeMedicine);
    }

    // Steps: "walked 6000 steps", "6000 steps", "log 8000 steps".
    if (RegExp(r'\bsteps?\b|\bwalk(?:ed|ing)?\b').hasMatch(q)) {
      final m = RegExp(r'\b(\d{2,6})\b').firstMatch(q.replaceAll(',', ''));
      final v = m != null ? int.tryParse(m.group(1)!) : null;
      if (v != null && v >= 100 && v <= 100000) {
        return ParsedCommand(CommandKind.logSteps, {'steps': v});
      }
    }

    // Sleep: "slept 7 hours", "slept 7.5h", "8 hours of sleep". Requires an
    // explicit duration so questions like "how did I sleep?" route to Q&A.
    if (RegExp(r'\bsle(?:pt|ep)\b|\bhours? of sleep\b').hasMatch(q)) {
      final hm = RegExp(r'\b(\d{1,2}(?:\.\d)?)\s*(?:h|hr|hrs|hour|hours)\b')
          .firstMatch(q);
      final h = hm != null ? double.tryParse(hm.group(1)!) : null;
      if (h != null && h >= 1 && h <= 16) {
        return ParsedCommand(CommandKind.logSleep, {'minutes': (h * 60).round()});
      }
    }

    // Period: "period started", "started my period", "log period", "on my period".
    if (RegExp(r'\bperiod\b|\bmenstruat').hasMatch(q) &&
        RegExp(r'\b(start|started|begin|began|log|today|got|on)\b').hasMatch(q)) {
      return const ParsedCommand(CommandKind.logPeriod);
    }

    return const ParsedCommand(CommandKind.none);
  }

  // ---------------------------------------------------------------------------
  // Reminders — natural-language parsing
  // ---------------------------------------------------------------------------
  ParsedReminder parseReminder(String input) {
    final base = _parseReminderBase(input);
    final lower = input.toLowerCase();
    final lead = _leadMinutes(lower);
    final untilDone = _untilDone(lower);
    if (lead == null && !untilDone) return base;

    var time = base.time;
    DateTime? event;
    if (lead != null && time != null) {
      event = time;
      var shifted = time.subtract(Duration(minutes: lead));
      final now = clock.now();
      // A heads-up that would already have gone by, for an event still ahead, is
      // sent straight away rather than silently not at all.
      if (shifted.isBefore(now) && time.isAfter(now) && base.repeat == 'none') {
        shifted = now.add(const Duration(minutes: 1));
      }
      time = shifted;
    }
    return base.copyWith(
      time: time,
      leadMinutes: event == null ? null : lead,
      eventTime: event,
      untilDone: untilDone,
    );
  }

  /// "30 min before", "an hour before", "half an hour before", "2 hours ahead":
  /// how much earlier than the event to fire, or null. Bounded to a day: a lead
  /// longer than that is a different reminder.
  int? _leadMinutes(String lower) {
    const tail = r'(?:before|ahead|early|beforehand|prior)\b';
    if (RegExp(r'\bhalf\s+(?:an?\s+)?hour\s+' + tail).hasMatch(lower)) return 30;
    if (RegExp(r'\b(?:an?|one)\s+hour\s+' + tail).hasMatch(lower)) return 60;
    final m = RegExp(r'\b(\d+)\s*(minutes?|mins?|hours?|hrs?)\s+' + tail)
        .firstMatch(lower);
    if (m == null) return null;
    final n = int.parse(m.group(1)!);
    final minutes = m.group(2)!.startsWith('h') ? n * 60 : n;
    return minutes >= 1 && minutes <= 24 * 60 ? minutes : null;
  }

  /// "until done", "until I do it", "keep reminding me", "nag me", "don't let me
  /// forget": the person wants it followed up until they act on it.
  bool _untilDone(String lower) => _untilDonePatterns.any((p) => p.hasMatch(lower));

  static final List<RegExp> _untilDonePatterns = [
    RegExp(
        r"\buntil\s+(?:i(?:'m|\s+am)?\s+)?(?:it(?:'s|\s+is)\s+)?(?:done|finished|complete|completed|ticked(?:\s+off)?|checked(?:\s+off)?)\b"),
    RegExp(r"\buntil\s+i\s+(?:do|did|have\s+done|finish|finished|tick|check)(?:\s+it)?\b"),
    RegExp(r'\bkeep\s+(?:reminding|nagging|pinging)\s+me\b'),
    RegExp(r'\bnag\s+me\b'),
    RegExp(r"\b(?:don'?t|do\s+not)\s+let\s+me\s+forget\b"),
  ];

  ParsedReminder _parseReminderBase(String input) {
    final text = input.trim();
    final lower = text.toLowerCase();
    // `clock.now()` so a test can pin the wall clock with `withClock`. Every
    // branch below is relative to now ("tomorrow", "next week", "at 8"), so with
    // `DateTime.now()` the suite could only ever assert ranges, never the actual
    // instant a phrase should resolve to.
    final now = clock.now();

    var repeat = _repeat(lower);
    final priority = _priority(lower);
    final category = _category(lower);
    List<int>? customDays;
    final durationMinutes = _parseDuration(lower);
    // Richer repeats than the six-value vocabulary can express. Null means the
    // phrase was ordinary and `repeat` above already covers it.
    final rrule = _recurrenceRule(lower);
    final endsAt = _untilDate(lower);
    final occurrenceLimit = _occurrenceLimit(lower);

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
        recurrenceRule: rrule,
        endsAt: endsAt,
        occurrenceLimit: occurrenceLimit,
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
        recurrenceRule: rrule,
        endsAt: endsAt,
        occurrenceLimit: occurrenceLimit,
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
        recurrenceRule: rrule,
        endsAt: endsAt,
        occurrenceLimit: occurrenceLimit,
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
      recurrenceRule: rrule,
      endsAt: endsAt,
      occurrenceLimit: occurrenceLimit,
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

  /// An RFC 5545 rule for the repeats the six-value [_repeat] vocabulary cannot
  /// express, or null to fall back to it.
  ///
  /// Deliberately narrow. It recognises the phrasings people actually type —
  /// "every other Tuesday", "every 3 days", "every 2 weeks", "monthly" — and
  /// declines everything else rather than guessing: a wrong rule is a reminder
  /// that fires on the wrong days indefinitely, which is worse than falling back
  /// to a plain weekly one the user can see and correct.
  ///
  /// Stays a string so this file needs no dependency on `rrule`; the feature
  /// layer parses it.
  String? _recurrenceRule(String lower) {
    const byDay = {
      'monday': 'MO',
      'tuesday': 'TU',
      'wednesday': 'WE',
      'thursday': 'TH',
      'friday': 'FR',
      'saturday': 'SA',
      'sunday': 'SU',
    };

    String withBounds(String base) {
      final count = _occurrenceLimit(lower);
      if (count != null) return '$base;COUNT=$count';
      final until = _untilDate(lower);
      if (until != null) {
        final u = until.toUtc();
        String two(int v) => v.toString().padLeft(2, '0');
        return '$base;UNTIL=${u.year}${two(u.month)}${two(u.day)}'
            'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
      }
      return base;
    }

    // "every other <weekday>" / "every 2nd <weekday>"
    final otherDay = RegExp(
            r'\bevery\s+(other|2nd|second)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?\b')
        .firstMatch(lower);
    if (otherDay != null) {
      return withBounds(
          'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=${byDay[otherDay.group(2)]}');
    }

    // "every other day" / "every other week"
    final otherUnit =
        RegExp(r'\bevery\s+(other|2nd|second)\s+(day|week|month)s?\b')
            .firstMatch(lower);
    if (otherUnit != null) {
      const freq = {'day': 'DAILY', 'week': 'WEEKLY', 'month': 'MONTHLY'};
      return withBounds(
          'RRULE:FREQ=${freq[otherUnit.group(2)]};INTERVAL=2');
    }

    // "every 3 days" / "every 2 weeks" / "every 6 months"
    final everyN =
        RegExp(r'\bevery\s+(\d+)\s*(day|week|month)s?\b').firstMatch(lower);
    if (everyN != null) {
      final n = int.parse(everyN.group(1)!);
      // "every 1 day" is just daily; the legacy path handles it and produces a
      // cheaper repeating notification.
      if (n > 1 && n <= 365) {
        const freq = {'day': 'DAILY', 'week': 'WEEKLY', 'month': 'MONTHLY'};
        return withBounds(
            'RRULE:FREQ=${freq[everyN.group(2)]};INTERVAL=$n');
      }
    }

    // "monthly" / "every month"
    if (RegExp(r'\b(monthly|every month|each month)\b').hasMatch(lower)) {
      return withBounds('RRULE:FREQ=MONTHLY');
    }
    // "yearly" / "annually"
    if (RegExp(r'\b(yearly|annually|every year|each year)\b').hasMatch(lower)) {
      return withBounds('RRULE:FREQ=YEARLY');
    }

    // A bounded plain repeat still needs a rule to carry the bound.
    final base = _repeat(lower);
    if (base == 'daily' || base == 'weekly') {
      if (_occurrenceLimit(lower) != null || _untilDate(lower) != null) {
        return withBounds(
            'RRULE:FREQ=${base == 'daily' ? 'DAILY' : 'WEEKLY'}');
      }
    }
    return null;
  }

  /// "5 times", "for 10 occurrences".
  int? _occurrenceLimit(String lower) {
    final m = RegExp(r'\b(\d+)\s*(times|occurrences)\b').firstMatch(lower);
    if (m == null) return null;
    final n = int.parse(m.group(1)!);
    return (n > 0 && n <= 999) ? n : null;
  }

  /// "until 5 july", "until july 5", "until 2026-07-05".
  DateTime? _untilDate(String lower) {
    const months = {
      'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5,
      'june': 6, 'july': 7, 'august': 8, 'september': 9, 'october': 10,
      'november': 11, 'december': 12,
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'jun': 6, 'jul': 7,
      'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final iso = RegExp(r'\buntil\s+(\d{4})-(\d{1,2})-(\d{1,2})\b')
        .firstMatch(lower);
    if (iso != null) {
      return DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!),
          int.parse(iso.group(3)!), 23, 59, 59);
    }
    final names = months.keys.join('|');
    final dayFirst =
        RegExp('\\buntil\\s+(\\d{1,2})(?:st|nd|rd|th)?\\s+($names)\\b')
            .firstMatch(lower);
    if (dayFirst != null) {
      return _untilFor(
          months[dayFirst.group(2)]!, int.parse(dayFirst.group(1)!));
    }
    final monthFirst =
        RegExp('\\buntil\\s+($names)\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b')
            .firstMatch(lower);
    if (monthFirst != null) {
      return _untilFor(
          months[monthFirst.group(1)]!, int.parse(monthFirst.group(2)!));
    }
    return null;
  }

  /// A month/day with no year means the NEXT such date, not one in the past.
  DateTime? _untilFor(int month, int day) {
    if (day < 1 || day > 31) return null;
    final now = clock.now();
    var candidate = DateTime(now.year, month, day, 23, 59, 59);
    if (candidate.isBefore(now)) {
      candidate = DateTime(now.year + 1, month, day, 23, 59, 59);
    }
    return candidate;
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
      // A heads-up ("30 min before", "an hour before") and "until done" are
      // instructions to the scheduler, not part of what to be reminded of.
      RegExp(
          r'\b(half\s+(an?\s+)?hour|(an?|one)\s+hour|\d+\s*(minutes?|mins?|hours?|hrs?))\s+(before|ahead|early|beforehand|prior)\b',
          caseSensitive: false),
      for (final p in _untilDonePatterns)
        RegExp(p.pattern, caseSensitive: false),
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
    if (RegExp(r'\b(once|1x|once a day|once daily|qd|od|qhs)\b').hasMatch(lower)) {
      freq = 'once daily';
    } else if (RegExp(r'\b(twice|2x|two times|bid|b\.i\.d)\b').hasMatch(lower)) {
      freq = 'twice daily';
    } else if (RegExp(r'\b(thrice|3x|three times|tid|t\.i\.d)\b').hasMatch(lower)) {
      freq = 'thrice daily';
    } else if (RegExp(r'\b(four times|4x|qid|q\.i\.d)\b').hasMatch(lower)) {
      freq = 'four times daily';
    } else if (RegExp(r'\b(as needed|prn|when needed)\b').hasMatch(lower)) {
      freq = 'asNeeded';
    } else if (RegExp(r'every\s+(\d+)\s*(hours?|h)\b').hasMatch(lower) ||
        RegExp(r'\bq(\d+)h\b').hasMatch(lower)) {
      freq = 'everyXHours';
      final m = RegExp(r'every\s+(\d+)\s*(?:hours?|h)\b').firstMatch(lower) ??
          RegExp(r'\bq(\d+)h\b').firstMatch(lower);
      res['intervalHours'] = int.tryParse(m!.group(1)!);
    } else if (lower.contains('daily') || lower.contains('every day')) {
      freq = 'once daily';
    }
    if (freq != null) res['frequency'] = freq;

    // Meal / food timing anchors.
    if (RegExp(r'\b(with food|with meals?|after (a )?meals?|with breakfast|with lunch|with dinner|after eating)\b')
        .hasMatch(lower)) {
      res['withFood'] = true;
    } else if (RegExp(r'\b(empty stomach|before (a )?meals?|before food|before eating|without food)\b')
        .hasMatch(lower)) {
      res['withFood'] = false;
    }
    for (final anchor in const {
      'breakfast': 'breakfast',
      'lunch': 'lunch',
      'dinner': 'dinner',
      'bedtime': 'bedtime',
      'before bed': 'bedtime',
      'at night': 'bedtime',
      'in the morning': 'morning',
      'morning': 'morning',
      'evening': 'evening',
    }.entries) {
      if (lower.contains(anchor.key)) {
        res['mealTiming'] = anchor.value;
        break;
      }
    }

    // Explicit clock times ("8am and 8pm", "at 9:00 and 21:00") → HH:mm list.
    final times = <String>[];
    for (final m
        in RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b').allMatches(lower)) {
      var h = int.parse(m.group(1)!);
      final min = m.group(2) != null ? int.parse(m.group(2)!) : 0;
      final ap = m.group(3);
      if (ap == 'pm' && h < 12) h += 12;
      if (ap == 'am' && h == 12) h = 0;
      if (h <= 23 && min <= 59) {
        times.add('${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}');
      }
    }
    if (times.isNotEmpty) res['times'] = times.toSet().toList()..sort();

    var name = input;
    name = name.replaceAll(
        RegExp(r'\d+(?:\.\d+)?\s*(mg|mcg|g|ml|iu|units?)', caseSensitive: false),
        ' ');
    name = name.replaceAll(
        RegExp(
            r'\b(once|twice|thrice|four times|two times|three times|a day|per day|daily|every day|as needed|prn|when needed|tablet|capsule|liquid|syrup|injection|drops|cream|inhaler|patch|take|of|qd|od|bid|tid|qid|qhs)\b',
            caseSensitive: false),
        ' ');
    name = name.replaceAll(RegExp(r'every\s+\d+\s*(hours?|h)\b', caseSensitive: false), ' ');
    name = name.replaceAll(RegExp(r'\bq\d+h\b', caseSensitive: false), ' ');
    // Meal / food / clock-time phrases.
    name = name.replaceAll(
        RegExp(
            r'\b(with|before|after|without)\s+(food|meals?|breakfast|lunch|dinner|eating)\b',
            caseSensitive: false),
        ' ');
    name = name.replaceAll(
        RegExp(r'\b(empty stomach|before bed|bedtime|at night|in the morning|morning|evening)\b',
            caseSensitive: false),
        ' ');
    name = name.replaceAll(RegExp(r'\b\d{1,2}(?::\d{2})?\s*(am|pm)\b', caseSensitive: false), ' ');
    name = name.replaceAll(RegExp(r'\band\b|\bat\b', caseSensitive: false), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    // A bare strength number left standing in the name with no unit
    // (e.g. "Dolo 650", "Vitamin D3 1000") is the medicine STRENGTH, not a dose
    // count. Pull it out so the wizard's strength field is populated and the
    // name stays clean. Only a whole standalone 2–4 digit token qualifies, so
    // vitamin names that fuse a digit ("B12", "D3", "K2") are preserved, and we
    // never override a unit-tagged dose already captured above.
    if (res['dosageAmount'] == null && res['strength'] == null) {
      final tokens = name.split(' ');
      final numIdx =
          tokens.indexWhere((t) => RegExp(r'^\d{2,4}$').hasMatch(t));
      if (numIdx != -1) {
        res['strength'] = tokens[numIdx];
        tokens.removeAt(numIdx);
        name = tokens.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }

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
    bool isRestricted = false,
    /// The user's real waking window. Defaults keep old callers working, but
    /// every production caller now passes `WaterService.wakingWindow()` — pacing
    /// against office hours told night-shift users they were always ahead.
    int wakeMinutes = 7 * 60,
    int sleepMinutes = 23 * 60,
  }) {
    final remaining = (goalMl - intakeMl).clamp(0, goalMl);
    final pct = goalMl > 0 ? (intakeMl / goalMl * 100).round() : 0;
    final streak = streakDays > 0 ? ' Your $streakDays-day streak is looking great!' : '';

    // Under a prescribed fluid ceiling every line below is wrong — they all
    // encourage drinking more, which is the opposite of the clinical advice the
    // user is following. No streak framing either: there is nothing to
    // congratulate about approaching a limit.
    if (isRestricted && goalMl > 0) {
      final left = goalMl - intakeMl;
      if (left < 0) {
        return 'You are ${-left}ml over your ${goalMl}ml daily limit. Worth '
            'mentioning to your clinician if it happens often.';
      }
      if (left == 0) {
        return 'You have reached your ${goalMl}ml daily limit for today.';
      }
      if (pct >= 80) {
        return 'Close to your limit — ${left}ml left of ${goalMl}ml today.';
      }
      return '${intakeMl}ml of your ${goalMl}ml limit so far. ${left}ml left.';
    }

    if (intakeMl >= goalMl && goalMl > 0) {
      return '🎉 Goal reached — ${intakeMl}ml today! Keep sipping to stay ahead.$streak';
    }

    // Pace-aware nudge: compare intake to where you'd be if on track for THIS
    // point in the day, not just the daily total. (mid-hour estimate for time.)
    final pace = HydrationPacer.compute(
      intakeMl: intakeMl,
      goalMl: goalMl,
      nowMinutes: hour * 60 + 30,
      wakeMinutes: wakeMinutes,
      sleepMinutes: sleepMinutes,
    );

    if (hour < 10) {
      return 'Good morning! A glass now is a strong start toward your ${goalMl}ml goal.$streak';
    }
    // With nothing logged yet there is no pace to be behind — the whole elapsed
    // day would read as a deficit ("you're 1,800ml behind"), which is just the
    // goal restated as a failure. Invite the first log instead.
    if (intakeMl <= 0) {
      return 'Nothing logged yet today. Add your first drink and I\'ll track your pace toward ${goalMl}ml.$streak';
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

  /// One line of context under the timer. Warm, and never a threat.
  ///
  /// The previous version opened with *"Keep your 3-day streak alive — a single
  /// 25-minute session today does it."* That is loss aversion: it frames the
  /// session as avoiding a punishment rather than doing something worthwhile, and
  /// CHI 2020 found streak anxiety to be the leading reason people abandon
  /// habit-tracking apps — rigid-streak users being **63% more likely to quit
  /// after a single missed day**. Duolingo's own answer is a *silent* streak
  /// freeze, which moves 14-day retention from ~19 to ~31 days.
  ///
  /// This app already computes that forgiveness — `StreakEngine` forgives one miss
  /// per rolling week — and never told anyone. So the user got the protection with
  /// none of the reassurance, which is the half that does the work. [usedGraceDay]
  /// says it out loud, retroactively, the way Duolingo does.
  ///
  /// [bestHour] and [suggestedMinutes] are both nullable and both stay unsaid when
  /// null: they come from `FocusInsights`, which returns null below five sessions.
  /// One suggestion at a time, never a dashboard of advice.
  String focusCoach({
    required int todayMinutes,
    required int streakDays,
    required int totalSessions,
    bool usedGraceDay = false,
    int? bestHour,
    int? suggestedMinutes,
    FocusReadinessNote? readiness,
  }) {
    // The length to name when suggesting one. Falls back to the classic pomodoro
    // only while there is not enough history to know better.
    final len = suggestedMinutes ?? 25;

    // Readiness outranks everything, and only before the first session of the
    // day. It is the only line here that knows something the user might not, and
    // its whole value is arriving BEFORE they choose a length — offered after
    // they have already focused it would just be second-guessing work they have
    // done. Still one line and one suggestion, like every other branch.
    if (todayMinutes == 0 && readiness != null) {
      return readiness.line;
    }

    if (todayMinutes == 0) {
      if (usedGraceDay && streakDays > 0) {
        return 'Yesterday is covered by a grace day — you\'re still on '
            '$streakDays. A $len-minute session carries it on.';
      }
      if (streakDays > 0) {
        return '$streakDays-day streak. One $len-minute session keeps it going.';
      }
      if (bestHour != null) {
        return 'You focus best around ${FocusInsights.hourLabel(bestHour)}. '
            'A $len-minute session is a good place to start.';
      }
      // "start" is load-bearing: `coach_text_test.dart` asserts the first-run line
      // is a start prompt, and that contract predates this rewrite. Changing the
      // copy to satisfy it was the right way round — weakening a test to match
      // new wording is how a suite stops describing anything.
      return totalSessions > 0
          ? 'Nothing yet today. A $len-minute session is plenty.'
          : 'One $len-minute session is a good place to start.';
    }

    if (todayMinutes < len) {
      return '${todayMinutes}m in today. Another short session if you have it '
          'in you — and no harm if not.';
    }

    final streak = streakDays > 0 ? ', $streakDays-day streak' : '';
    return '${todayMinutes}m focused today$streak. That\'s a good day\'s work.';
  }

  static String _commas(int n) {
    final s = n.abs().toString();
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// Deterministic activity coach. Pace- and time-aware, mirrors [hydrationTip].
  String stepsTip({
    required int steps,
    required int goal,
    required int streakDays,
    required int hour,
  }) {
    final pct = goal > 0 ? (steps / goal * 100).round() : 0;
    final streak =
        streakDays > 0 ? ' Your $streakDays-day streak is going strong!' : '';
    if (goal > 0 && steps >= goal) {
      return '🎉 Goal reached — ${_commas(steps)} steps today! Every extra step is a bonus.$streak';
    }
    if (steps == 0) {
      return hour < 11
          ? 'Fresh start — a short morning walk gets your ${_commas(goal)}-step day moving.'
          : 'No steps logged yet. A 10-minute walk (~1,000 steps) is an easy first win.';
    }
    final short = (goal - steps).clamp(0, goal);
    if (hour >= 18 && short > 0) {
      final mins = (short / 100).ceil().clamp(1, 120);
      return 'You\'re at $pct% (${_commas(steps)} of ${_commas(goal)}). A brisk $mins-min walk closes the gap.$streak';
    }
    return 'On the move — $pct% of your goal (${_commas(short)} to go). Keep it up.$streak';
  }

  /// Deterministic sleep coach — duration, debt and consistency aware.
  String sleepTip({
    required int lastNightMinutes,
    required int targetMinutes,
    required int debtMinutes,
    required double regularity,

    /// Nights actually logged in the debt window. Below 4 the debt figure is
    /// dominated by missing data, so it is not mentioned.
    int loggedNights = 7,

    /// When given, the debt line is judged and worded from the weighted
    /// 14-night debt (with its catch-up plan) instead of [debtMinutes].
    SleepDebtResult? weightedDebt,
  }) {
    if (lastNightMinutes <= 0) {
      return 'Log last night\'s sleep and I\'ll track your duration, consistency and sleep debt.';
    }
    final dur = '${lastNightMinutes ~/ 60}h ${lastNightMinutes % 60}m';
    if (lastNightMinutes >= targetMinutes) {
      return '😴 $dur last night — you hit your target. A steady schedule keeps it that way.';
    }
    // Only mention debt when the week is actually well logged. `sleepDebtMinutes`
    // totals target-minus-actual across the window, so 2 logged nights out of 7
    // produced a "debt" that was really just 5 unlogged nights.
    final behind = weightedDebt;
    if (behind != null) {
      if (behind.debtMinutes >= 180 && behind.nights >= SleepDebt.minNights) {
        return '$dur last night. ${behind.behindLine}';
      }
    } else if (debtMinutes >= 180 && loggedNights >= 4) {
      return '$dur last night, and about ${(debtMinutes / 60).round()}h of sleep debt this week. An earlier night or two helps you recover.';
    }
    if (regularity < 0.5) {
      return '$dur last night. Your bedtimes vary a lot — a more regular wind-down time improves quality more than duration alone.';
    }
    final shortM = targetMinutes - lastNightMinutes;
    return '$dur last night — about ${(shortM / 60).toStringAsFixed(1)}h under target. Try starting your wind-down a little earlier tonight.';
  }

  /// Deterministic, HONEST cycle coach. Fertility is always an estimate and
  /// never framed as contraception-grade; nothing here is a diagnosis.
  String cycleInsight({
    int? daysUntilNextPeriod,
    bool inFertileWindow = false,
    bool isLate = false,
    int lateDays = 0,
    bool irregular = false,
    bool learning = false,
    bool pregnancy = false,
    int? cycleDay,
  }) {
    if (pregnancy) {
      return 'Pregnancy mode is on — cycle predictions are paused. You can still log symptoms any time.';
    }
    if (learning) {
      return 'Still learning your cycle. Log each period start and I\'ll predict your next one, your phases and fertile window — with a confidence you can see.';
    }
    if (isLate && lateDays >= 1) {
      return 'Your period is about $lateDays day${lateDays == 1 ? '' : 's'} past the estimate. Cycles naturally vary — log any flow to update the prediction. (Not a diagnosis.)';
    }
    if (daysUntilNextPeriod != null &&
        daysUntilNextPeriod >= 0 &&
        daysUntilNextPeriod <= 3) {
      return daysUntilNextPeriod == 0
          ? 'Your period is estimated to start today, based on your own logged cycles.'
          : 'Your period is estimated in about $daysUntilNextPeriod day${daysUntilNextPeriod == 1 ? '' : 's'}, based on your own logged cycles.';
    }
    if (inFertileWindow) {
      return 'You may be in your estimated fertile window${cycleDay != null ? ' (cycle day $cycleDay)' : ''}. This is a calendar estimate — not reliable for contraception.';
    }
    if (irregular) {
      return 'Your recent cycles vary quite a bit, so predictions are less certain. If that continues, a clinician can help — this isn\'t a diagnosis.';
    }
    if (cycleDay != null) {
      return 'You\'re on day $cycleDay of your cycle. Logging flow and symptoms sharpens your predictions.';
    }
    return 'Log your period days and symptoms and I\'ll surface your phase, next-period estimate and trends.';
  }

  String dailyBriefing({
    /// Doses with no outcome yet — not `total - taken`.
    ///
    /// It used to be `medsTaken`, and this derived `medsTotal - medsTaken`,
    /// which counts a *missed* or deliberately *skipped* dose as one you still
    /// have to take. On device that put "You still have 5 doses left — a good
    /// moment to take them" directly above a Medicine card reading "Nothing
    /// left today · 1 of 6 taken": the same five doses, described two
    /// incompatible ways, from one summary object. Telling someone to take a
    /// dose they deliberately skipped is the worse half of that.
    required int medsOutstanding,
    required int medsTotal,
    required int waterPct,
    required int focusMinutes,
    required int remindersLeft,
    required int hour,
    /// True when the user is under a prescribed fluid ceiling rather than
    /// working toward a hydration goal. See [_crossSignal].
    bool isRestricted = false,
    int steps = 0,
    int stepGoal = 0,
    int sleepMinutes = 0,

    /// Today was marked a rest or unwell day: the step goal is paused, so the
    /// strip has nothing to say about it.
    bool restDay = false,
  }) {
    // Deliberately NOT prefixed with a greeting or a stats recap.
    //
    // This strip used to return
    //   '$greeting! Today so far: meds 1/2 · water 40%. $nudge'
    // which, clamped to two lines on a phone, reliably truncated the nudge —
    // the one clause that tells the user what to DO — in order to spend its
    // budget on a greeting the header already showed and a set of numbers the
    // pulse row renders directly beneath it. The nudge alone fits with room to
    // spare and is the only part that isn't already on screen.
    return _crossSignal(
      medsLeft: medsOutstanding,
      medsTotal: medsTotal,
      waterPct: waterPct,
      focusMinutes: focusMinutes,
      remindersLeft: remindersLeft,
      hour: hour,
      isRestricted: isRestricted,
      steps: steps,
      stepGoal: stepGoal,
      sleepMinutes: sleepMinutes,
      restDay: restDay,
    );
  }

  /// Under this, last night counts as a short one.
  static const int shortNightMinutes = 6 * 60;

  static String _hm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// The single most useful CROSS-FEATURE suggestion — reasoning across meds,
  /// water, focus and reminders together (our differentiator; a per-feature tip
  /// can't see the whole day). Priority-ordered, deterministic.
  String _crossSignal({
    required int medsLeft,
    required int medsTotal,
    required int waterPct,
    required int focusMinutes,
    required int remindersLeft,
    required int hour,
    bool isRestricted = false,
    int steps = 0,
    int stepGoal = 0,
    int sleepMinutes = 0,
    bool restDay = false,
  }) {
    // `waterPct` is progress toward a GOAL for most users and progress toward
    // a prescribed CEILING for a fluid-restricted one — [HydrationProfile]
    // returns `fluidCeilingMl` as the effective goal under a restriction. The
    // two read identically here, so "behind" on a ceiling means "safely under
    // the limit your clinician set", and every water line below would urge a
    // dialysis or heart-failure patient toward that limit.
    //
    // [hydrationTip] in this same file already refuses to do that, in as many
    // words: "Under a prescribed fluid ceiling every line below is wrong —
    // they all encourage drinking more, which is the opposite of the clinical
    // advice the user is following." This strip is on the Home screen, above
    // the fold, and it had no such guard.
    final waterBehind = !isRestricted && waterPct < 60;
    // Unfinished doses late in the day is the highest-priority health signal.
    if (medsTotal > 0 && medsLeft > 0 && hour >= 18) {
      return 'You still have $medsLeft dose${medsLeft == 1 ? '' : 's'} left — '
          'a good moment to take ${medsLeft == 1 ? 'it' : 'them'} before the evening winds down.';
    }
    // A short night, in the first half of the day: the one thing here that
    // changes how the rest of the day should be paced, and it is only useful
    // before the afternoon. Nothing is claimed when no night was recorded.
    if (sleepMinutes > 0 && sleepMinutes < shortNightMinutes && hour < 14) {
      return 'A short night — ${_hm(sleepMinutes)}. Go easy on yourself today, '
          'and an earlier night tonight will help.';
    }
    // Cross-signal: water behind AND a dose due → one glass covers both.
    if (waterBehind && medsTotal > 0 && medsLeft > 0) {
      return 'A glass of water now closes your hydration gap and pairs perfectly with your next dose.';
    }
    if (waterBehind) {
      return 'Your water is a little behind — a glass now keeps you on track.';
    }
    // Early evening, short of the step goal. `steps > 0`: with no steps read at
    // all there is nothing to measure the goal against, and a phone that does
    // not count steps is not "8,000 behind".
    final stepsToGo = stepGoal - steps;
    if (!restDay &&
        steps > 0 &&
        stepsToGo > 0 &&
        hour >= 17 &&
        hour < 21) {
      final mins = StepReminderPlanner.walkMinutes(stepsToGo);
      return '${StepReminderPlanner.groupThousands(stepsToGo)} steps to go — '
          'about $mins ${mins == 1 ? 'minute' : 'minutes'} of walking closes '
          'your step goal.';
    }
    if (focusMinutes == 0 && hour >= 9 && hour < 20) {
      return 'No focus time yet — a single 25-minute session builds momentum.';
    }
    if (remindersLeft > 0) {
      return 'You\'ve got this.';
    }
    if (!restDay && steps > 0 && stepGoal > 0 && steps >= stepGoal) {
      return 'Everything\'s on track — and your step goal is done.';
    }
    return 'Everything\'s on track — nicely done.';
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
