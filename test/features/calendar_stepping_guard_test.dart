import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Calendar days are not 24 hours.
///
/// Across a DST transition a civil day is 23 or 25 hours, so stepping a local
/// `DateTime` with an absolute `Duration` lands on the wrong calendar day — or
/// on the right day at the wrong hour. `lib/core/utils/calendar_day.dart` exists
/// to do this correctly: `dayOffset` / `prevDay` / `nextDay` for day keys,
/// `startOfWeek` for week buckets, and `shiftCalendarDays` when a time of day
/// must be preserved.
///
/// The arithmetic itself is proven in `test/core/dst_date_arithmetic_probe.dart`,
/// which runs under `TZ=America/New_York`. That probe cannot reach these call
/// sites — the focus models and water charts both pull in `package:flutter`,
/// and a Dart process cannot change its timezone after start — so this scan is
/// what stops a call site regressing to the broken shape. It is a source scan,
/// and its limits are real: it proves the expression is absent, not that the
/// surrounding logic is right.
void main() {
  // Every one of these keys its data by calendar day and buckets it by week.
  //
  // Sleep and steps are scoped to `services/` rather than the whole feature:
  // those two files own every day key, every window bound and every night
  // attribution the features store, and they are what the DST probe drives. The
  // screens still carry Duration stepping in "Yesterday" labels and chart
  // ranges; that is real, and it is not what this guard claims to cover.
  const roots = <String>[
    'lib/features/focus',
    'lib/features/water',
    'lib/features/sleep/services',
    'lib/features/steps/services',
  ];

  // The defect is the STEPPING call form. A bare `Duration(days: 90)` used as a
  // window size (e.g. WaterService.warmCacheWindow) is fine and must not trip
  // this — only `.add(...)` / `.subtract(...)` of a whole-day Duration is
  // date arithmetic.
  final stepping = RegExp(r'\.(add|subtract)\(\s*(?:const\s+)?Duration\(\s*days:');

  test('no Duration-based day stepping in focus or water', () {
    final offenders = <String>[];

    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) {
        fail('$root does not exist — this guard is scanning nothing');
      }
      for (final f in dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Skip comments — the fixes deliberately name the old shape in prose
          // so the reason survives, and a guard that fires on its own
          // explanation is a guard people delete.
          final code = line.split('//').first;
          if (stepping.hasMatch(code)) {
            offenders.add('${f.path}:${i + 1}  ${line.trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Use calendar_day.dart instead of Duration stepping:\n'
          '  dayOffset(d, n) / prevDay / nextDay  — day keys\n'
          '  startOfWeek(d)                       — week buckets\n'
          '  shiftCalendarDays(d, n)              — keeps the time of day\n'
          '${offenders.join('\n')}',
    );
  });

  test('the scanner actually sees code (it can fail)', () {
    // A scan that silently reads nothing passes forever. Prove the regex
    // matches the shape it is written for.
    final stepping =
        RegExp(r'\.(add|subtract)\(\s*(?:const\s+)?Duration\(\s*days:');
    expect(stepping.hasMatch('final x = d.add(const Duration(days: 1));'), isTrue);
    expect(stepping.hasMatch('final x = d.subtract(Duration(days: 6 - i));'), isTrue);
    // ...and does NOT match a plain duration constant.
    expect(
        stepping.hasMatch('static const w = Duration(days: 90);'), isFalse);
    // ...nor a correct call.
    expect(stepping.hasMatch('final x = dayOffset(d, -7);'), isFalse);
  });
}
