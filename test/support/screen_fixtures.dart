/// Arguments for the screens the responsive harnesses cannot build with `const`.
///
/// Shared rather than copied. Both harnesses register the same screens, and a
/// fixture that drifted between them would mean the tap-target audit and the
/// overflow sweep were measuring two different screens under one name — the
/// duplication problem `test/support/text_layout.dart` already exists to avoid.
///
/// Each takes the harness's pinned "now" instead of reading the clock: the QA
/// seed anchors its history to that instant, and a fixture on the wall clock
/// stops overlapping the seeded window the moment the suite runs 30 days later.
library;

import 'package:tablet_remainder/features/biometrics/models/biometric_metric.dart';
import 'package:tablet_remainder/features/biometrics/models/health_source.dart';
import 'package:tablet_remainder/features/biometrics/services/connected_devices_controller.dart';
import 'package:tablet_remainder/features/medication/models/doctor_pharmacy.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';

/// The id `qa_seed` writes for its second medicine.
const String kSeededMedicineId = 'seed-med-1';

/// The medicine `qa_seed` writes as [kSeededMedicineId], rebuilt.
///
/// The detail screen takes the medicine as an argument and then reads its OWN
/// history back by id — logs, adherence, refill. Handing it a freshly-invented
/// id renders the same empty screen at every device size, which is how a screen
/// gets registered and measured without ever being rendered with data in it —
/// the exact hole that seeding these harnesses was meant to close. Matching the
/// seeded id is what makes the dose list, the adherence figure and the stock
/// row real.
///
/// `createdAt` is backdated by `days + 1` and `startDate` by `days` (30 at the
/// default seed profile) because that is what the seed does, and because an
/// adherence denominator that ignores slots from before the medicine existed
/// degenerates to 100% for a medicine created "now".
EnhancedMedicine seededMedicine(DateTime seedNow) => EnhancedMedicine(
      id: kSeededMedicineId,
      name: 'Lisinopril',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      currentStock: 37,
      lowStockThreshold: 10,
      createdAt: seedNow.subtract(const Duration(days: 31)),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.twiceDaily,
        times: [
          ScheduledTime(hour: 8, minute: 0, label: 'Morning'),
          ScheduledTime(hour: 20, minute: 0, label: 'Evening'),
        ],
        startDate: seedNow.subtract(const Duration(days: 30)),
      ),
    );

/// The source id [seededSourceController] puts in the registry.
const String kFixtureSourceId = 'src_fixture_watch';

/// A devices controller already holding one source.
///
/// `ConnectedDevicesController()` constructs fine on its defaults, but its
/// `sources` start null and `HealthSourceDetailScreen` then renders only its
/// "This source is gone" empty state — a registration that measures the empty
/// state and reports the screen clean. Seeding `value` is the point: this is a
/// `ValueNotifier` and the screen reads the row out of it on every build.
///
/// The long device name is deliberate. `displayName` is vendor/user supplied,
/// so it is the unbounded string on this screen, and an unbounded string in a
/// header is what the overflow sweep exists to catch.
ConnectedDevicesController seededSourceController(DateTime seedNow) {
  final seen = seedNow.subtract(const Duration(days: 2));
  return ConnectedDevicesController()
    ..value = ConnectedDevicesState(
      phase: DevicesPhase.complete,
      sources: [
        HealthSource(
          id: kFixtureSourceId,
          sourceId: 'com.samsung.android.wear.shealth',
          sourceName: 'Galaxy Watch6 Classic 47mm',
          platformIndex: 0,
          metrics: {
            BiometricMetricKey.restingHr:
                SourceMetricStat(lastSeenAt: seen, points: 120),
            BiometricMetricKey.hrv:
                SourceMetricStat(lastSeenAt: seen, points: 90),
          },
          firstSeenAt: seedNow.subtract(const Duration(days: 60)),
          lastSeenAt: seen,
          createdAt: seedNow.subtract(const Duration(days: 60)),
          updatedAt: seen,
        ),
      ],
    );
}

/// A visit five days off, with every optional field filled and the longest
/// plausible doctor name and place: the Visit brief reads the seeded medicines
/// and logs behind it, and its heading and lines are what can overflow.
Appointment seededAppointment(DateTime seedNow) => Appointment(
      id: 'seed-appt-1',
      doctorName: 'Dr Anand Venkataraghavan, Consultant Endocrinologist',
      dateTime: seedNow.add(const Duration(days: 5)),
      location: "St Mary's Hospital, East Wing, Clinic 3",
      purpose: 'Six-month review of blood pressure and the new tablets',
      notes: 'Ask about the dizziness in the mornings',
      reminderEnabled: false,
    );
