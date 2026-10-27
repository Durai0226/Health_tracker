import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Something was just queued": a nudge from the isolate that heard a notification
/// button, to the one that can act on it.
///
/// A button on a notification runs in a background isolate with no database, so
/// what it asked for is parked in a queue and applied by the main isolate — on
/// its next resume. If the app is already open, nothing resumes: a Done tapped on
/// a heads-up banner over the open Reminders list would not show until the app
/// was next backgrounded and returned to. This is the missing tap on the
/// shoulder.
class QueueSignal {
  const QueueSignal._();

  static const String portName = 'dlyminder_queue_arrived';

  /// Tell whichever isolate is [listen]ing that a queue just changed. Never
  /// throws, and says nothing when no one is listening (the app is closed, which
  /// is the case the resume drain already covers).
  static void notify() {
    try {
      ui.IsolateNameServer.lookupPortByName(portName)?.send('arrived');
    } catch (_) {}
  }

  /// Run [onArrived] each time a queue changes, until the returned function is
  /// called. One listener at a time: a second [listen] replaces the first, which
  /// is what a rebuilt shell wants.
  static void Function() listen(VoidCallback onArrived) {
    final port = ReceivePort();
    ui.IsolateNameServer.removePortNameMapping(portName);
    ui.IsolateNameServer.registerPortWithName(port.sendPort, portName);
    final sub = port.listen((_) => onArrived());
    return () {
      sub.cancel();
      port.close();
      // Only if it is still ours: a newer listener may have taken the name.
      final current = ui.IsolateNameServer.lookupPortByName(portName);
      if (current == port.sendPort) {
        ui.IsolateNameServer.removePortNameMapping(portName);
      }
    };
  }

  /// SharedPreferences with whatever another isolate has written since this one
  /// last looked.
  ///
  /// Each isolate keeps its own in-memory copy, read once. The queues are written
  /// by one isolate and drained by another, so without a reload the drain sees
  /// the copy it loaded at start — empty — and a button tapped while the app sat
  /// alive in the background is invisible until the process is killed and
  /// restarted. A write that starts from a stale copy would also wipe out what
  /// the other isolate had queued.
  static Future<SharedPreferences> freshPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (e) {
      debugPrint('⚠️ preference reload failed: $e');
    }
    return prefs;
  }
}
