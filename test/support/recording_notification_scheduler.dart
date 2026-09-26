import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tablet_remainder/core/services/notification_scheduler.dart';
import 'package:timezone/timezone.dart' as tz;

/// One `zonedSchedule` call, as the OS would have received it.
class RecordedSchedule {
  RecordedSchedule({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    required this.mode,
    required this.matchDateTimeComponents,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime when;
  final AndroidScheduleMode mode;
  final DateTimeComponents? matchDateTimeComponents;
  final String? payload;

  /// Whether this registration is exact — i.e. whether the OS will fire it to
  /// the minute or inside its own batching window.
  bool get isExact => const {
        AndroidScheduleMode.exact,
        AndroidScheduleMode.exactAllowWhileIdle,
        AndroidScheduleMode.alarmClock,
      }.contains(mode);

  @override
  String toString() => 'RecordedSchedule($id, $when, ${mode.name})';
}

/// One `show` call.
class RecordedShow {
  RecordedShow(this.id, this.title, this.body, this.payload);

  final int id;
  final String? title;
  final String? body;
  final String? payload;

  @override
  String toString() => 'RecordedShow($id, $title)';
}

/// Records what would have been asked of the OS, instead of asking it.
///
/// The double behind `NotificationScheduler`. Before it existed there was no way
/// to stand in for `FlutterLocalNotificationsPlugin`, so every invariant about
/// scheduling in this app was asserted by grepping its own source — which passes
/// on code that is spelled right and behaves wrong.
///
/// It lives in `test/support` rather than beside the production implementation
/// (where `RecordingReminderAlarm` and `RecordingFocusSessionAlarm` live) because
/// nothing in `lib` needs it, and it carries failure-injection knobs
/// ([exactAllowed], [refuseExactMidCall], [midCallError]) that would be dead
/// weight in a shipped binary. The cost of that choice is that adding a method to
/// `NotificationScheduler` breaks this file rather than the app's own build — so
/// `dart analyze test/` is what catches it.
class RecordingNotificationScheduler implements NotificationScheduler {
  RecordingNotificationScheduler({this.exactAllowed = true});

  /// What [exactAlarmsAllowed] answers — the Android 14+ `SCHEDULE_EXACT_ALARM`
  /// grant. `false` is the DEFAULT state on a fresh Android 14 install, not an
  /// edge case.
  bool exactAllowed;

  /// Ids whose first EXACT attempt throws [midCallError], for the racy case: the
  /// grant is revoked between the capability check and the call. The id is
  /// removed once it has thrown, so a retry gets through — which is what makes
  /// "fell back" and "propagated" distinguishable from each other.
  final Set<int> refuseExactMidCall = <int>{};

  /// What [refuseExactMidCall] throws. Defaults to the exact shape the plugin
  /// raises when Android refuses; override it to check that a failure which is
  /// NOT a permission refusal propagates rather than being quietly retried.
  Object midCallError = PlatformException(
    code: 'exact_alarms_not_permitted',
    message: 'Exact alarms are not permitted',
  );

  /// Ids whose [cancel] throws [cancelError], for callers that withdraw a
  /// registration OUTSIDE a try. `NotificationService.cancelNotification` does
  /// not guard `_scheduler.cancel`, so a failure there escapes every method
  /// that withdraws before it re-arms — which is the only way to reach the
  /// error path of a caller whose `schedule…` is itself internally guarded.
  final Set<int> failCancel = <int>{};

  /// What [failCancel] throws.
  Object cancelError = PlatformException(
    code: 'cancel_failed',
    message: 'The notification could not be withdrawn',
  );

  /// What [pendingNotificationRequests] answers.
  List<PendingNotificationRequest> pending = <PendingNotificationRequest>[];

  final List<RecordedSchedule> scheduled = <RecordedSchedule>[];
  final List<RecordedShow> shown = <RecordedShow>[];
  final List<int> cancelled = <int>[];
  int cancelAllCount = 0;

  /// How many times the exact-alarm capability was queried. A check per item in
  /// a loop is a platform round trip per item for an answer that cannot change.
  int exactAlarmChecks = 0;

  /// The order operations happened in: `arm:<id>@<mode>`, `cancel:<id>`,
  /// `cancelAll`, `show:<id>`.
  ///
  /// Ordering is load-bearing. Arming a new id before cancelling the old one
  /// orphans the old registration, leaving an alarm nothing can cancel.
  final List<String> sequence = <String>[];

  /// Ids currently armed, in arming order, last write winning.
  List<int> get armedIds => scheduled.map((s) => s.id).toList();

  RecordedSchedule? lastFor(int id) {
    for (var i = scheduled.length - 1; i >= 0; i--) {
      if (scheduled[i].id == id) return scheduled[i];
    }
    return null;
  }

  void clear() {
    scheduled.clear();
    shown.clear();
    cancelled.clear();
    sequence.clear();
    cancelAllCount = 0;
    exactAlarmChecks = 0;
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime when,
    NotificationDetails details, {
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    const exactModes = {
      AndroidScheduleMode.exact,
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.alarmClock,
    };
    if (exactModes.contains(androidScheduleMode) &&
        refuseExactMidCall.remove(id)) {
      throw midCallError;
    }
    scheduled.add(RecordedSchedule(
      id: id,
      title: title,
      body: body,
      when: when,
      mode: androidScheduleMode,
      matchDateTimeComponents: matchDateTimeComponents,
      payload: payload,
    ));
    sequence.add('arm:$id@${androidScheduleMode.name}');
  }

  @override
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? details, {
    String? payload,
  }) async {
    shown.add(RecordedShow(id, title, body, payload));
    sequence.add('show:$id');
  }

  @override
  Future<void> cancel(int id) async {
    if (failCancel.contains(id)) throw cancelError;
    cancelled.add(id);
    sequence.add('cancel:$id');
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    sequence.add('cancelAll');
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async =>
      pending;

  @override
  Future<bool> exactAlarmsAllowed() async {
    exactAlarmChecks++;
    return exactAllowed;
  }
}
