/// "What goes with better days", at the layer that feeds it: the mood log.
///
/// The pattern arithmetic is covered in `mood_tags_test.dart`; this is the wiring
/// in `InsightService.gatherAll` — which entries it reads, how it folds several
/// entries on one day into a day, and which window it looks at.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/utils/calendar_day.dart';
import 'package:tablet_remainder/features/insights/services/insight_service.dart';
import 'package:tablet_remainder/features/medication/models/mood_entry.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await StepService.resetForTesting();
    await SleepService.resetForTesting();
  });

  tearDown(() async => database.close());

  var seq = 0;
  Future<void> mood(DateTime day, int index, {List<String> tags = const []}) {
    final at = DateTime(day.year, day.month, day.day, 9, seq++ % 50);
    return VitalsStorageService.saveMood(MoodEntry(
        id: 'm${at.microsecondsSinceEpoch}-$seq',
        moodIndex: index,
        takenAt: at,
        tags: tags,
        createdAt: at));
  }

  Future<Insight?> tagInsight(String tag) async {
    for (final i in await InsightService.gatherAll()) {
      if (i.id == 'mood_tag_$tag') return i;
    }
    return null;
  }

  /// [n] days WITH the tag all Great, and [n] without it all Bad, counted back
  /// from [from] days ago.
  Future<void> seedSplit(int n, {int from = 1, String tag = 'walk'}) async {
    for (var i = 0; i < n; i++) {
      await mood(dayOffset(today(), -(from + i)), 0, tags: [tag]);
      await mood(dayOffset(today(), -(from + n + i)), 3);
    }
  }

  test('a tag that goes with better days is reported, with its sample',
      () async {
    await seedSplit(6);
    final i = (await tagInsight('walk'))!;
    expect(i.title, 'Mood tends to be better on days with a walk');
    expect(i.severity, InsightSeverity.good);
    expect(i.evidence!.groupA, 6);
    expect(i.evidence!.groupB, 6);
  });

  test('and one that goes with lower days says so, without alarm', () async {
    for (var n = 1; n <= 6; n++) {
      await mood(dayOffset(today(), -n), 4, tags: ['short_night']);
      await mood(dayOffset(today(), -n - 10), 1);
    }
    final i = (await tagInsight('short_night'))!;
    expect(i.title, contains('lower'));
    expect(i.severity, InsightSeverity.info);
  });

  test('several entries on one day are ONE day: averaged, tags pooled', () async {
    // Each tagged day has three entries — Good, Great, Good — and the tag is on
    // the MIDDLE one only, so neither the first nor the last entry carries it.
    // Counted per entry the tagged group would be 18 "days"; per day it is 6,
    // and the day's mood is the mean of the three: (3 + 4 + 3) / 3.
    for (var n = 1; n <= 6; n++) {
      await mood(dayOffset(today(), -n), 1);
      await mood(dayOffset(today(), -n), 0, tags: ['walk']);
      await mood(dayOffset(today(), -n), 1);
      await mood(dayOffset(today(), -n - 10), 3);
    }
    final i = (await tagInsight('walk'))!;
    expect(i.evidence!.groupA, 6);
    expect(i.evidence!.groupB, 6);
    expect(i.detail, contains('3.3 out of 4'));
  });

  test('a pattern from two months ago still counts', () async {
    await seedSplit(6, from: 50);
    expect((await tagInsight('walk'))!.evidence!.groupA, 6);
  });

  test('entries older than 90 days are not part of it', () async {
    // The whole pattern is further back than the window: nothing to report.
    await seedSplit(6, from: 95);
    expect(await tagInsight('walk'), isNull);
  });

  test('days with no tags make no pattern', () async {
    for (var n = 1; n <= 12; n++) {
      await mood(dayOffset(today(), -n), n.isEven ? 0 : 4);
    }
    final all = await InsightService.gatherAll();
    expect(all.where((i) => i.id.startsWith('mood_tag_')), isEmpty);
  });

  test('too few days with the tag make no pattern', () async {
    for (var n = 1; n <= 3; n++) {
      await mood(dayOffset(today(), -n), 0, tags: ['walk']);
    }
    for (var n = 1; n <= 8; n++) {
      await mood(dayOffset(today(), -n - 10), 4);
    }
    expect(await tagInsight('walk'), isNull);
  });
}
