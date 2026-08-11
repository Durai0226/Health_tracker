import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';

/// Injection-site rotation: suggesting the NEXT site in a fixed rotation
/// list from a medicine's past logs, so the user doesn't keep injecting the
/// same spot. [suggestNextInjectionSite] is a pure function over
/// already-fetched logs — no DB access — so it's tested directly here.
void main() {
  MedicineLog logWithSite(String site, DateTime actionTime) => MedicineLog(
        id: 'log_${actionTime.millisecondsSinceEpoch}',
        medicineId: 'med1',
        scheduledTime: actionTime,
        actionTime: actionTime,
        status: MedicineStatus.taken,
        vitals: {'injectionSite': site},
      );

  group('suggestNextInjectionSite', () {
    test('positive: cycles to the site after the most recent log\'s site', () {
      final logs = [
        logWithSite(injectionSites[0], DateTime(2026, 1, 1)),
        logWithSite(injectionSites[1], DateTime(2026, 1, 8)),
        logWithSite(injectionSites[2], DateTime(2026, 1, 15)), // most recent
      ];
      expect(suggestNextInjectionSite(logs), injectionSites[3]);
    });

    test('positive: wraps around past the end of the rotation list', () {
      final logs = [logWithSite(injectionSites.last, DateTime(2026, 1, 1))];
      expect(suggestNextInjectionSite(logs), injectionSites.first);
    });

    test(
        'positive: picks the log with the latest actionTime, regardless of list order',
        () {
      final logs = [
        // Listed first but scheduled/actioned LAST — must still win.
        logWithSite(injectionSites[3], DateTime(2026, 1, 20)),
        logWithSite(injectionSites[0], DateTime(2026, 1, 1)),
        logWithSite(injectionSites[1], DateTime(2026, 1, 10)),
      ];
      expect(suggestNextInjectionSite(logs), injectionSites[4]);
    });

    test('negative: no past logs suggests the first site without throwing',
        () {
      expect(() => suggestNextInjectionSite(const []), returnsNormally);
      expect(suggestNextInjectionSite(const []), injectionSites.first);
    });

    test(
        'negative: past logs with no site info anywhere suggest the first site without throwing',
        () {
      final logs = [
        MedicineLog(
          id: 'log1',
          medicineId: 'med1',
          scheduledTime: DateTime(2026, 1, 1),
          status: MedicineStatus.taken,
        ),
        MedicineLog(
          id: 'log2',
          medicineId: 'med1',
          scheduledTime: DateTime(2026, 1, 2),
          status: MedicineStatus.taken,
          vitals: {'someOtherKey': 'value'}, // vitals set, but no site
        ),
      ];
      expect(() => suggestNextInjectionSite(logs), returnsNormally);
      expect(suggestNextInjectionSite(logs), injectionSites.first);
    });

    test(
        'negative: a recorded site no longer present in the rotation list falls back to the first site',
        () {
      final logs = [logWithSite('Some retired site', DateTime(2026, 1, 1))];
      expect(() => suggestNextInjectionSite(logs), returnsNormally);
      expect(suggestNextInjectionSite(logs), injectionSites.first);
    });
  });

  group('injectionSites constant', () {
    test('has 6 distinct, non-empty sites', () {
      expect(injectionSites.length, 6);
      expect(injectionSites.toSet().length, 6); // no duplicates
      expect(injectionSites.every((s) => s.trim().isNotEmpty), isTrue);
    });
  });
}
