/// The memory of which health-store samples have been brought in, which is what
/// lets a deletion stick.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/health/import_ledger.dart';

void main() {
  const ledger = ImportLedger('seen', cap: 5);

  test('adds to the end, oldest first', () {
    expect(ledger.appended(['a', 'b'], ['c']), ['a', 'b', 'c']);
  });

  test('past the cap the oldest go, and the newest stay', () {
    expect(ledger.appended(['a', 'b', 'c', 'd'], ['e', 'f', 'g']),
        ['c', 'd', 'e', 'f', 'g']);
  });

  test('exactly at the cap nothing goes', () {
    expect(ledger.appended(['a', 'b', 'c'], ['d', 'e']), ['a', 'b', 'c', 'd', 'e']);
  });

  test('one batch bigger than the cap keeps its own newest', () {
    expect(ledger.appended(const [], ['1', '2', '3', '4', '5', '6', '7']),
        ['3', '4', '5', '6', '7']);
  });

  group('ids still inside the next window', () {
    // An app that writes a reading every few minutes puts thousands of ids into
    // the week the next run reads again. Dropped by age alone, a reading the person
    // had deleted came back at that run.
    test('go last: the oldest that are NOT wanted go first', () {
      expect(
          ledger.appended(['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'], ['i'], keep: {'a', 'b'}),
          ['a', 'b', 'g', 'h', 'i']);
    });

    test('more of them than the cap: all are kept, and nothing else', () {
      final all = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'];

      expect(ledger.appended(all.sublist(0, 8), ['i'], keep: {'a', 'b', 'c', 'd', 'e', 'f', 'g'}),
          ['a', 'b', 'c', 'd', 'e', 'f', 'g']);
    });

    test('but never more than the hard cap, oldest first beyond it', () {
      const small = ImportLedger('seen', cap: 3, hardCap: 5);
      final ids = [for (var i = 0; i < 8; i++) 'id$i'];

      expect(small.appended(ids.sublist(0, 4), ids.sublist(4), keep: ids.toSet()),
          ['id3', 'id4', 'id5', 'id6', 'id7']);
    });

    test('ids that are not in the list change nothing', () {
      expect(
          ledger.appended(['a', 'b', 'c', 'd'], ['e', 'f', 'g'], keep: {'x', 'y'}),
          ['c', 'd', 'e', 'f', 'g']);
    });

    test('under the cap nothing is dropped, wanted or not', () {
      expect(ledger.appended(['a'], ['b'], keep: {'a'}), ['a', 'b']);
    });

    test('the survivors keep the order they had, newest last', () {
      // Two have to go: the oldest that are not wanted, a and c — not b, which is.
      expect(
          ledger.appended(['a', 'b', 'c', 'd', 'e'], ['f', 'g'], keep: {'b', 'e'}),
          ['b', 'd', 'e', 'f', 'g']);
    });

    test('remember passes it through to what is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('seen', ['a', 'b', 'c', 'd', 'e', 'f']);

      await ledger.remember(prefs, ledger.load(prefs), ['g', 'h'], keep: {'a'});

      expect(prefs.getStringList('seen'), ['a', 'e', 'f', 'g', 'h']);
    });
  });

  test('is remembered across loads, and empty before anything is', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(ledger.load(prefs), isEmpty);

    await ledger.remember(prefs, ledger.load(prefs), ['a', 'b']);
    await ledger.remember(prefs, ledger.load(prefs), ['c']);

    expect(ledger.load(prefs), ['a', 'b', 'c']);
    expect(prefs.getStringList('seen'), ['a', 'b', 'c']);
  });

  test('two ledgers on different keys do not share ids', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const other = ImportLedger('other');
    await ledger.remember(prefs, const [], ['a']);
    expect(other.load(prefs), isEmpty);
  });
}
