/// "Readings from other apps" has to be run from somewhere, and a switch that is
/// on while nothing ever calls it is the quietest way for this to stop working.
///
/// The shell is too large to stand up for this, so this is a source scan, with
/// the limits that has: it proves the call is there, not that the logic behind
/// it is right (the import tests do that).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final shell = File('lib/features/home/screens/app_shell.dart').readAsStringSync();

  test('the shell brings readings in at start-up and again on resume', () {
    expect('_importVitalsFromHealth();'.allMatches(shell).length, 2,
        reason: 'once from the first-frame callback, once from the resumed branch');
  });

  test('and does it through the gate, which checks the switch and the throttle', () {
    expect(shell, contains('VitalsHealthImport.runIfEnabled()'));
  });

  test('it never raises a toast: that would replace the Undo of a dose applied from a notification',
      () {
    final start = shell.indexOf('Future<void> _importVitalsFromHealth()');
    final end = shell.indexOf('Future<void> _drainQueuedDoseActions');
    expect(start, isNonNegative);
    final body = shell.substring(start, end);
    expect(body, isNot(contains('toast')));
  });

  group('the same for drinks from other apps', () {
    test('the shell counts them at start-up and again on resume', () {
      expect('_importWaterFromHealth();'.allMatches(shell).length, 2);
      expect(shell, contains('WaterHealthImport.runIfEnabled()'));
    });

    test('and raises no toast either', () {
      final start = shell.indexOf('Future<void> _importWaterFromHealth()');
      final end = shell.indexOf('Future<void> _drainQueuedDoseActions');
      expect(start, isNonNegative);
      expect(shell.substring(start, end), isNot(contains('toast')));
    });
  });
}
