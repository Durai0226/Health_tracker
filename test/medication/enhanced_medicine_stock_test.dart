import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';

/// QA — medicine stock / supply math (F2). Includes the regression for the
/// bug where an untracked medicine (stock persisted as 0, refill tracking off)
/// falsely reported "low stock" and "0 days remaining".
EnhancedMedicine med({
  int? stock,
  int? threshold = 7,
  bool refill = false,
  double dose = 1,
}) {
  return EnhancedMedicine(
    id: 'x',
    name: 'Test',
    dosageForm: DosageForm.tablet,
    dosageAmount: dose,
    currentStock: stock,
    lowStockThreshold: threshold,
    refillReminderEnabled: refill,
    schedule: MedicineSchedule(
      frequencyType: FrequencyType.onceDaily,
      times: [ScheduledTime(hour: 8, minute: 0)],
    ),
  );
}

void main() {
  group('isLowStock — refill-tracking gate (Bug A regression)', () {
    test('untracked med (refill off, stock coerced to 0) is NOT low', () {
      expect(med(stock: 0, refill: false).isLowStock, isFalse);
    });
    test('untracked med with null stock is NOT low', () {
      expect(med(stock: null, refill: false).isLowStock, isFalse);
    });
    test('tracked med below threshold IS low', () {
      expect(med(stock: 3, threshold: 7, refill: true).isLowStock, isTrue);
    });
    test('tracked med at threshold IS low (inclusive)', () {
      expect(med(stock: 7, threshold: 7, refill: true).isLowStock, isTrue);
    });
    test('tracked med above threshold is NOT low', () {
      expect(med(stock: 30, threshold: 7, refill: true).isLowStock, isFalse);
    });
  });

  group('estimatedDaysRemaining', () {
    test('untracked med returns -1 (unknown)', () {
      expect(med(stock: 0, refill: false).estimatedDaysRemaining, -1);
    });
    test('tracked once-daily med divides stock by per-day use', () {
      expect(med(stock: 30, refill: true, dose: 1).estimatedDaysRemaining, 30);
    });
  });

  group('stock mutation helpers', () {
    test('reduceStock ceils a fractional dose', () {
      expect(med(stock: 10, refill: true).reduceStock(0.5).currentStock, 9);
    });
    test('reduceStock clamps at 0', () {
      expect(med(stock: 1, refill: true).reduceStock(5).currentStock, 0);
    });
    test('reduceStock on untracked stock is a no-op', () {
      expect(med(stock: null, refill: true).reduceStock(1).currentStock, isNull);
    });
    test('restoreStock mirrors reduceStock (ceil)', () {
      expect(med(stock: 9, refill: true).restoreStock(0.5).currentStock, 10);
    });
    test('addStock adds units', () {
      expect(med(stock: 5, refill: true).addStock(10).currentStock, 15);
    });
  });

  /// One definition of "is this medicine's supply tracked", because three
  /// screens each had their own and all three were wrong differently.
  ///
  /// The honest test would be "did the user type a quantity", but that is not
  /// recoverable: `currentStock` is NOT NULL with a 0 default, the write
  /// coerces `?? 0` and the read maps the column straight across, so a blank
  /// quantity and a deliberate zero are the same stored row.
  group('isStockTracked', () {
    test('a quantity with reminders off is still tracked', () {
      // The add flow's step 2 is "optional — blank quantity means untracked",
      // and the quantity field is independent of the refill switch. Somebody
      // who typed 30 and left reminders off expects to see 30.
      expect(med(stock: 30, refill: false).isStockTracked, isTrue);
    });

    test('reminders on is tracked even at zero', () {
      // The case a `> 0` test got wrong: every taken dose runs reduceStock,
      // which clamps at 0, so the medicine would count down to "1 left" on the
      // Refill screen and then vanish from it — at the exact moment it needs
      // refilling.
      expect(med(stock: 0, refill: true).isStockTracked, isTrue);
    });

    test('no quantity and no reminders is untracked', () {
      // The case a `!= null` test got wrong: it matched every medicine, so the
      // detail screen printed a fabricated "0 pill(s) remaining".
      expect(med(stock: 0, refill: false).isStockTracked, isFalse);
      expect(med(stock: null, refill: false).isStockTracked, isFalse);
    });

    test('reminders on with stock is tracked', () {
      expect(med(stock: 30, refill: true).isStockTracked, isTrue);
    });

    test('it never disagrees with isLowStock about being tracked', () {
      // isLowStock is the other opt-in gate; a medicine it can flag must be
      // one this screen is willing to show.
      for (final m in [
        med(stock: 0, refill: true),
        med(stock: 3, refill: true),
        med(stock: 30, refill: true),
      ]) {
        if (m.isLowStock) {
          expect(m.isStockTracked, isTrue,
              reason: 'flagged low but hidden from the supply screen');
        }
      }
    });
  });
}
