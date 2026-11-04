/// The reminder history as a spreadsheet: one line for every time a reminder came
/// due — when, whether it was answered, and how.
///
/// Pure: rows in, text out. The part worth getting right is what a spreadsheet
/// does with the text.
///
/// **Quoting** follows RFC 4180: a cell with a comma, a quote or a line break in it
/// is wrapped in quotes, and a quote inside is doubled. Reminder titles are typed
/// by people and contain all three.
///
/// **A leading `=`, `+`, `-` or `@`** (or a tab or carriage return) is what makes a
/// spreadsheet run a cell as a formula. A reminder called `=HYPERLINK(…)` is data
/// somebody typed, and the file is one they may email — so the cell is made
/// plain text with a leading apostrophe, the defence the OWASP guidance for CSV
/// injection gives. It shows in the cell; that is the price of the file being safe
/// to open.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/utils/csv_cell.dart';

/// One time a reminder came due.
class HistoryRow {
  const HistoryRow({
    required this.title,
    required this.scheduledFor,
    this.firedAt,
    this.actedAt,
    required this.result,
    this.snoozeCount = 0,
  });

  /// What the reminder was called.
  final String title;

  /// When it was due.
  final DateTime scheduledFor;

  /// When the notification actually appeared; null if it never did.
  final DateTime? firedAt;

  /// When the person answered; null if they did not.
  final DateTime? actedAt;

  /// "Done", "Skipped", "Missed" or "Pending".
  final String result;

  /// How many times it was snoozed before it was resolved.
  final int snoozeCount;
}

abstract final class ReminderHistoryCsv {
  static const List<String> columns = [
    'Reminder',
    'Due',
    'Notified',
    'Answered',
    'Result',
    'Snoozed',
  ];

  /// The file's text: a header and then one line per row, oldest first.
  ///
  /// CRLF between lines, as the RFC has it. The text has no byte-order mark; the
  /// FILE does — see [encode].
  static String build(Iterable<HistoryRow> rows) {
    final ordered = rows.toList()
      ..sort((a, b) {
        final byTime = a.scheduledFor.compareTo(b.scheduledFor);
        return byTime != 0 ? byTime : a.title.compareTo(b.title);
      });
    final out = StringBuffer(columns.map(cell).join(','))..write('\r\n');
    for (final r in ordered) {
      out
        ..write([
          r.title,
          stamp(r.scheduledFor),
          r.firedAt == null ? '' : stamp(r.firedAt!),
          r.actedAt == null ? '' : stamp(r.actedAt!),
          r.result,
          '${r.snoozeCount}',
        ].map(cell).join(','))
        ..write('\r\n');
    }
    return out.toString();
  }

  /// The bytes to write to the file: [csv] as UTF-8 behind a byte-order mark.
  ///
  /// Without the mark Excel reads a UTF-8 file in the local ANSI code page, and a
  /// reminder called "Café", or anything in Tamil or Hindi, comes out as mojibake
  /// in the one program a file for a clinician is most likely to be opened in.
  /// Every other reader this is meant for — Numbers, Google Sheets, a text editor —
  /// takes the mark as what it is.
  static Uint8List encode(String csv) {
    final out = BytesBuilder(copy: false)
      ..add(_byteOrderMark)
      ..add(utf8.encode(csv));
    return out.toBytes();
  }

  static const List<int> _byteOrderMark = [0xEF, 0xBB, 0xBF];

  /// `2026-03-14 09:30`, local time — what a spreadsheet reads as a date.
  static String stamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  /// One cell: made safe to open, then quoted if it has to be. See [csvCell].
  static String cell(String value) => csvCell(value);
}
