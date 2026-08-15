@Tags(['performance'])
library;

/// Cold start must not scale with how long the app has been used, and must not
/// block the first frame on the network.
///
/// `WaterService.init()` and `StepService.init()` each ran a per-day query in a
/// loop over their warm-cache windows — 90 and 35 days — and both run BEFORE
/// `runApp()`. That is up to 91 + 36 serialized round trips standing between
/// tapping the icon and seeing a frame, growing with history.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

import '../support/counting_executor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CountingExecutor counter;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    counter = CountingExecutor(NativeDatabase.memory());
    db = AppDatabase.forTesting(counter);
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  /// Seeds [days] days of water history, then measures a genuinely COLD init.
  ///
  /// Both parts matter. `init()` early-returns on `_isInitialized`, so without
  /// the reset the second call measures nothing — and on an empty database the
  /// per-day loop never executes, so without seeding the old code and the new
  /// code look identical. The first version of this test made both mistakes
  /// and passed with the N+1 deliberately restored.
  Future<int> coldInitReads({required int days}) async {
    await WaterService.init();
    for (var i = 0; i < days; i++) {
      await WaterService.addWaterLogForDate(
        date: DateTime.now().subtract(Duration(days: i)),
        amountMl: 250,
        beverage: BeverageType.defaultBeverages.first,
      );
    }
    await WaterService.resetForTesting();

    counter.reset();
    await WaterService.init();
    return counter.selects;
  }

  test('water init cost does not grow with days of history', () async {
    final withThree = await coldInitReads(days: 3);

    await WaterService.resetForTesting();
    counter.reset();
    final withTwenty = await coldInitReads(days: 20);

    expect(
      withTwenty,
      withThree,
      reason: 'A cold WaterService.init() cost $withThree reads with 3 days of '
          'history and $withTwenty with 20. Startup must not scale with how '
          'long someone has used the app — the old per-day loop over the '
          '90-day warm-cache window meant up to 91 serialized round trips '
          'before runApp(). Tally: ${counter.tally}',
    );
    expect(withTwenty, lessThanOrEqualTo(8),
        reason: 'and it must be a small constant, not merely flat');
  });

  test('StepService.init reads a constant number of times', () async {
    counter.reset();
    await StepService.init();
    expect(
      counter.selects,
      lessThanOrEqualTo(6),
      reason: 'StepService.init issued ${counter.selects} reads; the old loop '
          'over a 35-day window cost up to 36. Tally: ${counter.tally}',
    );
  });
}
