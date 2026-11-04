/// The reminder history as a CSV: every line is a time a reminder came due, and the
/// text has to survive being opened in a spreadsheet — whatever somebody typed as a
/// reminder's name.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_history_csv.dart';

void main() {
  final t = DateTime(2026, 3, 14, 9, 30);

  HistoryRow row({
    String title = 'Take a walk',
    DateTime? due,
    DateTime? fired,
    DateTime? acted,
    String result = 'Done',
    int snoozes = 0,
  }) =>
      HistoryRow(
        title: title,
        scheduledFor: due ?? t,
        firedAt: fired,
        actedAt: acted,
        result: result,
        snoozeCount: snoozes,
      );

  List<String> lines(String csv) => csv.split('\r\n')..removeLast();

  group('the file', () {
    test('is a header and nothing else when there is no history', () {
      expect(ReminderHistoryCsv.build(const []),
          'Reminder,Due,Notified,Answered,Result,Snoozed\r\n');
    });

    test('has one line for every time a reminder came due', () {
      final csv = ReminderHistoryCsv.build([
        row(
          due: t,
          fired: t.add(const Duration(minutes: 2)),
          acted: t.add(const Duration(minutes: 4)),
          snoozes: 1,
        ),
      ]);

      expect(lines(csv), [
        'Reminder,Due,Notified,Answered,Result,Snoozed',
        'Take a walk,2026-03-14 09:30,2026-03-14 09:32,2026-03-14 09:34,Done,1',
      ]);
    });

    test('leaves a time blank when it never happened', () {
      final csv = ReminderHistoryCsv.build([row(result: 'Missed')]);

      expect(lines(csv).last, 'Take a walk,2026-03-14 09:30,,,Missed,0');
    });

    test('is in the order things came due, oldest first, however it was given', () {
      final csv = ReminderHistoryCsv.build([
        row(title: 'B', due: DateTime(2026, 3, 14, 12)),
        row(title: 'A', due: DateTime(2026, 3, 14, 12)),
        row(title: 'C', due: DateTime(2026, 3, 13, 8)),
      ]);

      expect(lines(csv).skip(1).map((l) => l.split(',').first), ['C', 'A', 'B']);
    });

    test('ends every line with CRLF, the last one too, and starts with no byte-order mark',
        () {
      final csv = ReminderHistoryCsv.build([row()]);

      expect(csv.endsWith('\r\n'), isTrue);
      expect('\r\n'.allMatches(csv).length, 2);
      expect(csv.codeUnitAt(0), isNot(0xFEFF));
    });

    test('keeps what is not ASCII', () {
      final csv = ReminderHistoryCsv.build([row(title: 'Médicament — matin ☀')]);

      expect(lines(csv).last, startsWith('Médicament — matin ☀,'));
    });

    test('pads the date', () {
      expect(ReminderHistoryCsv.stamp(DateTime(2026, 1, 2, 3, 4)), '2026-01-02 03:04');
      expect(ReminderHistoryCsv.stamp(DateTime(987, 11, 22, 23, 59)), '0987-11-22 23:59');
    });
  });

  group('one cell', () {
    test('plain text is left alone', () {
      expect(ReminderHistoryCsv.cell('Take a walk'), 'Take a walk');
      expect(ReminderHistoryCsv.cell(''), '');
    });

    test('a comma, a quote or a line break needs quotes, and a quote inside is doubled', () {
      expect(ReminderHistoryCsv.cell('Pills, morning'), '"Pills, morning"');
      expect(ReminderHistoryCsv.cell('Say "hi"'), '"Say ""hi"""');
      expect(ReminderHistoryCsv.cell('one\ntwo'), '"one\ntwo"');
      expect(ReminderHistoryCsv.cell('one\r\ntwo'), '"one\r\ntwo"');
      expect(ReminderHistoryCsv.cell('one\rtwo'), '"one\rtwo"', reason: 'a lone CR too');
    });

    test('leading or trailing space is kept by quoting it', () {
      expect(ReminderHistoryCsv.cell(' pad'), '" pad"');
      expect(ReminderHistoryCsv.cell('pad '), '"pad "');
    });

    test('a title with all of it survives a round trip', () {
      const title = 'Dr. "Ng", 3pm,\nbring forms';
      final csv = ReminderHistoryCsv.build([row(title: title)]);

      expect(csv, contains('"Dr. ""Ng"", 3pm,\nbring forms"'));
    });
  });

  group('a cell a spreadsheet would run', () {
    for (final lead in ['=', '+', '-', '@', '\t', '\r']) {
      final shown = lead.codeUnitAt(0) < 32 ? '\\u${lead.codeUnitAt(0).toRadixString(16)}' : lead;
      test('starting with $shown is made plain text', () {
        final out = ReminderHistoryCsv.cell('${lead}SUM(A1)');

        // A line break lead is quoted as well; either way the apostrophe is first
        // inside whatever quoting there is.
        final inner = out.startsWith('"') ? out.substring(1) : out;
        expect(inner.startsWith("'$lead"), isTrue, reason: out);
      });
    }

    test('a formula in a reminder\'s name does not reach the file as one', () {
      final csv = ReminderHistoryCsv.build([
        row(title: '=HYPERLINK("http://evil.example","click")'),
      ]);

      expect(csv, isNot(contains('\r\n=HYPERLINK')));
      expect(lines(csv)[1], startsWith('"\'=HYPERLINK('));
    });

    test('an ordinary title that merely contains one of them is not touched', () {
      expect(ReminderHistoryCsv.cell('Take 2+2 pills'), 'Take 2+2 pills');
      expect(ReminderHistoryCsv.cell('B-12 shot'), 'B-12 shot');
      expect(ReminderHistoryCsv.cell('mail @ noon'), 'mail @ noon');
    });

    test('a negative-looking title is made plain text too', () {
      // "-5 mg" is something a person types, and a spreadsheet reads as a number
      // or a formula; it gets the apostrophe like the rest.
      expect(ReminderHistoryCsv.cell('-5 mg'), "'-5 mg");
    });
  });

  group('the file', () {
    // Excel reads a UTF-8 file in the local ANSI code page unless it starts with a
    // byte-order mark, so a title in Tamil or Hindi — or just "Café" — came out as
    // mojibake in the program a file for a clinician is most likely to be opened in.
    test('is UTF-8 behind a byte-order mark', () {
      final bytes = ReminderHistoryCsv.encode('Reminder\r\nCafé\r\n');

      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.sublist(3)), 'Reminder\r\nCafé\r\n');
    });

    test('carries every script the way it was typed', () {
      const title = 'மாத்திரை — दवा — Café — 薬';
      final bytes = ReminderHistoryCsv.encode(ReminderHistoryCsv.cell(title));

      expect(utf8.decode(bytes.sublist(3)), title);
    });

    test('is the same text with three bytes in front, and nothing else changed', () {
      final text = ReminderHistoryCsv.build([row(title: 'Take a walk')]);
      final bytes = ReminderHistoryCsv.encode(text);

      expect(bytes.length, utf8.encode(text).length + 3);
      expect(bytes.sublist(3), utf8.encode(text));
    });

    test('an empty text is still a valid file: the mark alone', () {
      expect(ReminderHistoryCsv.encode(''), [0xEF, 0xBB, 0xBF]);
    });

    test('the text itself carries no mark: a reader that is told it is UTF-8 sees none', () {
      expect(ReminderHistoryCsv.build([row()]).codeUnitAt(0), isNot(0xFEFF));
    });
  });
}
