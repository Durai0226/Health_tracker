/// Opening hours that cross midnight are a normal entry, not an edge case.
///
/// The Operating hours editor gives every day two free time pickers, so
/// "20:00 - 08:00" is exactly how a night pharmacy or an A&E is recorded.
/// `isOpenNow` tested `now >= open && now <= close`, which assumes close comes
/// after open. At 22:00 on such a day that computed `1320 >= 1200` (true) and
/// `1320 <= 480` (false), so the clinic list drew a red "Closed" dot directly
/// beside the clinic's own "20:00 - 08:00" line.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/clinic.dart';

void main() {
  /// A clinic open [open]–[close] every day.
  OperatingHours everyDay(String open, String close) {
    const t = true;
    final d = DayHours(isOpen: t, openTime: open, closeTime: close);
    return OperatingHours(
      monday: d,
      tuesday: d,
      wednesday: d,
      thursday: d,
      friday: d,
      saturday: d,
      sunday: d,
    );
  }

  /// Is the clinic open at [hour]:[minute] on a Wednesday?
  bool openAt(OperatingHours hours, int hour, int minute) => withClock(
        Clock.fixed(DateTime(2026, 3, 11, hour, minute)),
        () => hours.isOpenNow,
      );

  group('hours that cross midnight', () {
    final overnight = everyDay('20:00', '08:00');

    test('open late in the evening', () {
      expect(openAt(overnight, 22, 0), isTrue,
          reason: 'the exact case on the screenshot: a red Closed dot beside '
              'the line reading "20:00 - 08:00"');
      expect(openAt(overnight, 20, 0), isTrue, reason: 'on the hour it opens');
      expect(openAt(overnight, 23, 59), isTrue);
    });

    test('still open after midnight', () {
      expect(openAt(overnight, 0, 30), isTrue);
      expect(openAt(overnight, 7, 59), isTrue);
      expect(openAt(overnight, 8, 0), isTrue, reason: 'on the hour it closes');
    });

    test('shut during the day', () {
      expect(openAt(overnight, 8, 1), isFalse);
      expect(openAt(overnight, 13, 0), isFalse);
      expect(openAt(overnight, 19, 59), isFalse);
    });
  });

  group('ordinary daytime hours are unchanged', () {
    final daytime = everyDay('09:00', '17:00');

    test('open inside, shut outside', () {
      expect(openAt(daytime, 9, 0), isTrue);
      expect(openAt(daytime, 13, 0), isTrue);
      expect(openAt(daytime, 17, 0), isTrue);
      expect(openAt(daytime, 8, 59), isFalse);
      expect(openAt(daytime, 17, 1), isFalse);
      expect(openAt(daytime, 2, 0), isFalse,
          reason: 'the wrap-around branch must not leak into normal hours');
    });
  });

  test('a day marked closed stays closed whatever the times say', () {
    final closed = OperatingHours(
      monday: const DayHours(isOpen: false, openTime: '20:00', closeTime: '08:00'),
      tuesday: const DayHours(isOpen: false),
      wednesday: const DayHours(isOpen: false, openTime: '20:00', closeTime: '08:00'),
      thursday: const DayHours(isOpen: false),
      friday: const DayHours(isOpen: false),
      saturday: const DayHours(isOpen: false),
      sunday: const DayHours(isOpen: false),
    );
    expect(openAt(closed, 22, 0), isFalse);
    expect(openAt(closed, 2, 0), isFalse);
  });
}
