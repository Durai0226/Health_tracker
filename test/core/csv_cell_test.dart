/// One cell of a CSV, written once.
///
/// Two exports each had their own copy of this and the copies had come apart. What
/// matters is that a cell cannot run as a formula on the computer that opens it, and
/// cannot break the row it is in.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/utils/csv_cell.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_history_csv.dart';

void main() {
  group('safe to open', () {
    test('what a spreadsheet would run as a formula is made text', () {
      for (final lead in ['=', '+', '-', '@']) {
        expect(csvCell('${lead}1+1'), "'${lead}1+1", reason: lead);
      }
      expect(csvCell('\tcmd'), "'\tcmd");
    });

    test('a carriage return in front is quoted as well, being a row break', () {
      expect(csvCell('\rcmd'), '"\'\rcmd"');
    });

    test('a formula is only one at the START of the cell', () {
      expect(csvCell('a=b'), 'a=b');
      expect(csvCell('x-ray'), 'x-ray');
    });
  });

  group('quoted when it has to be', () {
    test('a comma, a quote, a line break of either kind', () {
      expect(csvCell('a,b'), '"a,b"');
      expect(csvCell('say "hi"'), '"say ""hi"""');
      expect(csvCell('one\ntwo'), '"one\ntwo"');
      expect(csvCell('one\rtwo'), '"one\rtwo"',
          reason: 'left bare, it ends the row in the reader');
    });

    test('a space at either end, which a reader may trim', () {
      expect(csvCell(' padded'), '" padded"');
      expect(csvCell('padded '), '"padded "');
    });

    test('and not otherwise', () {
      expect(csvCell('Metformin'), 'Metformin');
      expect(csvCell(''), '');
      expect(csvCell('two words'), 'two words');
    });
  });

  test('the two exports that had a copy each say the same thing now', () {
    for (final cell in ['=SUM(A1)', 'a,b', 'one\rtwo', ' padded', 'plain', '@x', '']) {
      expect(ReminderHistoryCsv.cell(cell), csvCell(cell), reason: cell);
    }
  });
}
