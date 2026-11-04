import 'package:flutter/material.dart';

import '../services/health_data_service.dart';
import 'app/app_widgets.dart';

/// What "turn it on" does for an automatic import from the health store, whatever
/// it imports: ask if it has not been allowed, remember the choice, read straight
/// away, and say what happened.
///
/// Blood pressure and sugar, and drinks, each had their own copy of this, and a
/// fix to one — the choice left on after a failed first read — had to be made in
/// both. What is asked, read and said stays with each import; this is the order of
/// events around it, and the two failures that must not be confused:
///
///  * **The store did not answer** ([HealthReadException]): nothing is wrong with
///    the choice. It stays on, and the next run reads the same stretch again.
///  * **Anything else** (a reading that could not be saved, say): the choice is
///    taken back. The toast says it could not be switched on and the switch snaps
///    back to off, so what is stored has to say the same; left on, the silent
///    import at every app resume would go on behind a switch that reads off.
class HealthImportTurnOn {
  const HealthImportTurnOn._();

  /// True when it is now on.
  ///
  /// [report] says what came in, from the result of [read]; [declinedMessage] is
  /// said when the store does not allow it, and [silentMessage] when it is allowed
  /// but did not answer just now.
  static Future<bool> run<R>(
    BuildContext context, {
    required String name,
    required Future<bool> Function() allowed,
    required Future<bool> Function() ask,
    required Future<void> Function(bool enabled) setEnabled,
    required Future<R> Function() read,
    required String declinedMessage,
    required String silentMessage,
    required void Function(BuildContext context, R result) report,
    String failedMessage = 'Could not switch this on. Please try again.',
  }) async {
    var switchedOn = false;
    try {
      var granted = await allowed();
      if (!granted) granted = await ask();
      if (!granted) {
        if (context.mounted) context.toastInfo(declinedMessage);
        return false;
      }
      // Granted, and the person asked for this: it is switched on whether or not the
      // screen is still there to see it. Returning before this left the permission
      // held and remembered and the switch never saved — off, on the next visit, with
      // the grant already in place. What needs the screen is the talking, below.
      await setEnabled(true);
      switchedOn = true;
      final result = await read();
      if (!context.mounted) return true;
      report(context, result);
      return true;
    } on HealthReadException catch (e) {
      debugPrint('$name: the health store could not be read: $e');
      if (context.mounted) context.toastInfo(silentMessage);
      return true;
    } catch (e) {
      debugPrint('$name: turning on failed: $e');
      if (switchedOn) {
        try {
          await setEnabled(false);
        } catch (e) {
          debugPrint('$name: could not switch it back off: $e');
        }
      }
      if (context.mounted) context.toastError(failedMessage);
      return false;
    }
  }
}
