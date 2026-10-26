import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_add_medication_flow.dart';

/// Editing a medicine must not blank the stock of one that has run out.
EnhancedMedicine med({int? stock, bool tracked = false}) => EnhancedMedicine(
      id: 'm',
      name: 'Metformin',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      currentStock: stock,
      refillReminderEnabled: tracked,
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.onceDaily,
        times: [ScheduledTime(hour: 8, minute: 0)],
      ),
    );

void main() {
  test('a medicine with stock shows it', () {
    expect(stockFieldText(med(stock: 12)), '12');
    expect(stockFieldText(med(stock: 12, tracked: true)), '12');
  });

  test('a tracked medicine that has run out shows 0, not a blank', () {
    expect(stockFieldText(med(stock: 0, tracked: true)), '0',
        reason: 'blank here saves back as untracked and drops its refill '
            'reminders');
  });

  test('a tracked medicine with no stock figure shows 0', () {
    expect(stockFieldText(med(stock: null, tracked: true)), '0');
  });

  test('an untracked medicine stays blank (the mapper stores its stock as 0)',
      () {
    expect(stockFieldText(med(stock: 0)), '');
    expect(stockFieldText(med(stock: null)), '');
  });
}
