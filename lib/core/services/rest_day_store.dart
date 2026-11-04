import 'package:clock/clock.dart';

import '../health/rest_days.dart';
import 'clean_storage_service.dart';

/// Rest and unwell days, kept on this device. See [RestDays] for what marking a
/// day does.
class RestDayStore {
  const RestDayStore._();

  static const _key = 'rest_days';

  static List<RestDay> all() => RestDays.decodeAll(
      CleanStorageService.getAppPreference(_key, const <String>[]));

  static RestKind? kindOn(DateTime day) => RestDays.kindOn(all(), day);

  static RestKind? kindToday({DateTime? now}) => kindOn(now ?? clock.now());

  /// The days a steps streak must skip, up to and including today.
  static Set<DateTime> frozenDays({DateTime? now}) =>
      RestDays.frozenDays(all(), now ?? clock.now());

  /// Mark today. Replaces an earlier mark for the same day.
  static Future<void> markToday(RestKind kind, {DateTime? now}) {
    final t = now ?? clock.now();
    return CleanStorageService.setAppPreference(
        _key, RestDays.encodeAll(RestDays.mark(all(), t, kind, today: t)));
  }

  /// Mark today and the [count] - 1 days after it, for a rest of a few days. The
  /// days after today change nothing until they arrive: [frozenDays] stops at today.
  static Future<void> markDays(RestKind kind, int count, {DateTime? now}) {
    final t = now ?? clock.now();
    return CleanStorageService.setAppPreference(
        _key, RestDays.encodeAll(RestDays.markRun(all(), t, kind, count, today: t)));
  }

  /// Put the marks back as they were, for Undo: unlike clearing the days that were
  /// marked, it also gives back a mark that the new ones replaced.
  static Future<void> restore(List<RestDay> before) =>
      CleanStorageService.setAppPreference(_key, RestDays.encodeAll(before));

  static Future<void> clear(DateTime day) => CleanStorageService.setAppPreference(
      _key, RestDays.encodeAll(RestDays.unmark(all(), day)));
}
