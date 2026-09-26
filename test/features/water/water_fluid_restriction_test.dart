import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/coach_text.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

/// The category's dangerous blind spot.
///
/// Every hydration app, this one included, was built on "more is always
/// better". For someone on a prescribed fluid restriction — advanced CKD,
/// dialysis, heart failure — that inverts: the app set a target above their
/// limit, nagged them toward it, and awarded a badge for exceeding it by 20%.
/// A content analysis of 51 water apps found ONE that mentioned kidney stones
/// and ZERO that mentioned chronic kidney disease.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  final noon = DateTime(2026, 8, 21, 12);

  setUp(() async {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    WaterService.clearInMemory();
    await WaterService.resetForTesting();
    await withClock(Clock.fixed(noon), () => WaterService.init());
  });

  tearDown(() async => database.close());

  Future<void> restrictTo(int ml) => WaterService.saveProfile(
      WaterService.getProfile().copyWith(fluidCeilingMl: ml));

  group('the profile model', () {
    test('a ceiling makes the daily number a limit', () {
      final p = HydrationProfile(id: 'p', weightKg: 70, fluidCeilingMl: 1500);
      expect(p.isRestricted, isTrue);
      expect(p.effectiveGoalMl, 1500);
    });

    test('the ceiling overrides even an explicit custom goal', () {
      final p = HydrationProfile(
        id: 'p',
        weightKg: 70,
        customGoalMl: 4000,
        useCustomGoal: true,
        fluidCeilingMl: 1500,
      );
      expect(p.effectiveGoalMl, 1500,
          reason: 'a clinical limit must win over anything the user typed '
              'into the ordinary goal field');
    });

    test('the ceiling bypasses the calculator floor', () {
      // HydrationGoalCalculator floors targets at 1200 so an odd profile cannot
      // produce an accidental restriction — which means a real one, which may
      // legitimately be lower, has to go round it.
      final p = HydrationProfile(id: 'p', weightKg: 70, fluidCeilingMl: 800);
      expect(p.effectiveGoalMl, 800);
    });

    test('it can actually be lifted again', () {
      // `fluidCeilingMl: null` cannot mean "clear" in a ?? copyWith, and a
      // stale ceiling is the dangerous direction to fail in.
      final p = HydrationProfile(id: 'p', weightKg: 70, fluidCeilingMl: 1500);
      expect(p.copyWith(clearFluidCeiling: true).isRestricted, isFalse);
      expect(p.copyWith(weightKg: 80).isRestricted, isTrue,
          reason: 'an unrelated edit must not silently drop the restriction');
    });

    test('it survives a JSON round trip', () {
      final p = HydrationProfile(id: 'p', weightKg: 70, fluidCeilingMl: 1500);
      expect(HydrationProfile.fromJson(p.toJson()).fluidCeilingMl, 1500);
    });
  });

  group('the service', () {
    test('headroom counts down and can go negative', () async {
      await withClock(Clock.fixed(noon), () async {
        await restrictTo(1500);
        expect(WaterService.isFluidRestricted, isTrue);
        expect(WaterService.fluidHeadroomMl(), 1500);

        final water = WaterService.getBeverage('water')!;
        await WaterService.addWaterLogForDate(
            date: noon, amountMl: 1000, beverage: water, time: noon);
        expect(WaterService.fluidHeadroomMl(), 500);
        expect(WaterService.hasExceededFluidCeiling(), isFalse);

        await WaterService.addWaterLogForDate(
            date: noon, amountMl: 800, beverage: water, time: noon);
        expect(WaterService.fluidHeadroomMl(), -300);
        expect(WaterService.hasExceededFluidCeiling(), isTrue);
      });
    });

    test('headroom uses raw volume, not the hydration coefficient', () async {
      await withClock(Clock.fixed(noon), () async {
        await restrictTo(1000);
        // Spirits carry a negative coefficient. If headroom used effective
        // hydration, a shot would BUY BACK allowance against a cardiac or renal
        // limit. The kidney sees the millilitres.
        final spirits = WaterService.getBeverage('spirits')!;
        await WaterService.addWaterLogForDate(
            date: noon, amountMl: 400, beverage: spirits, time: noon);
        expect(WaterService.fluidHeadroomMl(), 600);
      });
    });

    test('an unrestricted profile reports no headroom concept', () {
      expect(WaterService.isFluidRestricted, isFalse);
      expect(WaterService.hasExceededFluidCeiling(), isFalse);
    });
  });

  group('the coach never tells a restricted user to drink more', () {
    const coach = CoachText();

    test('under the limit, it reports what is left', () {
      final t = coach.hydrationTip(
          intakeMl: 900,
          goalMl: 1500,
          streakDays: 5,
          hour: 14,
          isRestricted: true);
      expect(t.toLowerCase(), contains('limit'));
      expect(t.toLowerCase(), isNot(contains('keep sipping')));
      expect(t.toLowerCase(), isNot(contains('behind')));
      expect(t, isNot(contains('streak')),
          reason: 'there is nothing to congratulate about nearing a limit');
    });

    test('over the limit, it says so plainly without alarm', () {
      final t = coach.hydrationTip(
          intakeMl: 1800,
          goalMl: 1500,
          streakDays: 0,
          hour: 20,
          isRestricted: true);
      expect(t, contains('300ml over'));
      expect(t.toLowerCase(), contains('clinician'));
    });

    test('the ordinary mode is untouched', () {
      final t = coach.hydrationTip(
          intakeMl: 900, goalMl: 2500, streakDays: 3, hour: 14);
      expect(t.toLowerCase(), isNot(contains('limit')));
    });
  });
}
