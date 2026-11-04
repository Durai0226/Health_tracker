import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart' as db;
import '../../../core/services/clean_storage_service.dart';
import '../../../core/utils/calendar_day.dart';
import '../../../core/utils/share_file.dart';
import '../models/reminder_model.dart';
import 'reminder_history_csv.dart';

/// How far back to export.
enum HistoryRange {
  days30('Last 30 days'),
  days90('Last 90 days'),
  all('Everything');

  const HistoryRange(this.label);

  final String label;
}

/// The reminder history as a file to share: every time a reminder came due, when
/// it was answered and how (see [ReminderHistoryCsv]).
///
/// The occurrence log was built so adherence could be reported, and the screen
/// shows a percentage of it. This is the rows behind the percentage, for a
/// spreadsheet, a clinician or a person who wants to look for themselves.
class ReminderHistoryExport {
  const ReminderHistoryExport._();

  /// What a reminder is called in the file when it has since been deleted. The
  /// log outlives the reminder on purpose — it is the record that it once fired —
  /// and the title is not kept with it.
  static const String deletedTitle = '(deleted reminder)';

  /// Test seam: widget tests have no share sheet. Receives the file's text and its
  /// name; always null in a real build.
  @visibleForTesting
  static Future<void> Function(String csv, String fileName)? shareOverride;

  /// `dlyminder-reminders-20260314.csv`.
  static String fileName(DateTime now) =>
      'dlyminder-reminders-${DateFormat('yyyyMMdd').format(now)}.csv';

  /// Every occurrence that came due in [range] up to [now], named by its reminder.
  static Future<List<HistoryRow>> rows(HistoryRange range, {DateTime? now}) async {
    final to = now ?? clock.now();
    final from = switch (range) {
      HistoryRange.days30 => dayOffset(startOfDay(to), -30),
      HistoryRange.days90 => dayOffset(startOfDay(to), -90),
      HistoryRange.all => DateTime(2000),
    };
    final occurrences =
        await db.AppDatabase.instance.remindersDao.occurrencesBetween(from, to);
    if (occurrences.isEmpty) return const [];

    final titles = {
      for (final r in await CleanStorageService.getAllReminders()) r.id: r.title,
    };
    return [
      for (final o in occurrences)
        HistoryRow(
          title: titles[o.reminderId] ?? deletedTitle,
          scheduledFor: o.scheduledFor,
          firedAt: o.firedAt,
          actedAt: o.actedAt,
          result: _result(ReminderOutcome.fromName(o.outcome)),
          snoozeCount: o.snoozeCount,
        ),
    ];
  }

  static String _result(ReminderOutcome o) => switch (o) {
        ReminderOutcome.done => 'Done',
        ReminderOutcome.skipped => 'Skipped',
        ReminderOutcome.missed => 'Missed',
        ReminderOutcome.pending => 'Pending',
      };

  /// Build the file and open the share sheet. Returns how many lines it holds, or
  /// 0 when there was nothing in [range] — and then nothing is opened.
  static Future<int> share(HistoryRange range, {DateTime? now}) async {
    final list = await rows(range, now: now);
    if (list.isEmpty) return 0;
    final csv = ReminderHistoryCsv.build(list);
    final name = fileName(now ?? clock.now());

    final override = shareOverride;
    if (override != null) {
      await override(csv, name);
      return list.length;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(ReminderHistoryCsv.encode(csv), flush: true);
    await shareFile(file, mimeType: 'text/csv', text: 'Reminder history');
    return list.length;
  }
}
