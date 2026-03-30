import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/js_learning_tables.dart';

part 'js_learning_dao.g.dart';

@DriftAccessor(tables: [
  JsLevels,
  JsTopics,
  JsLessons,
  JsQuizzes,
  JsChallenges,
  JsTopicProgress,
  JsUserStats,
  JsDailyActivity,
  JsQuizAttempts,
  JsBookmarks,
  JsLessonNotes,
])
class JsLearningDao extends DatabaseAccessor<AppDatabase> with _$JsLearningDaoMixin {
  JsLearningDao(super.db);

  // ==================== LEVELS ====================

  Future<List<JsLevel>> getAllLevels() =>
      (select(jsLevels)..orderBy([(l) => OrderingTerm.asc(l.levelNumber)])).get();

  Future<JsLevel?> getLevelById(String id) =>
      (select(jsLevels)..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<List<JsLevel>> getUnlockedLevels() =>
      (select(jsLevels)
            ..where((l) => l.isUnlocked.equals(true))
            ..orderBy([(l) => OrderingTerm.asc(l.levelNumber)]))
          .get();

  Future<int> insertLevel(JsLevelsCompanion level) =>
      into(jsLevels).insert(level, mode: InsertMode.insertOrReplace);

  Future<void> insertLevels(List<JsLevelsCompanion> levels) async {
    await batch((batch) {
      batch.insertAll(jsLevels, levels, mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> unlockLevel(String levelId) async {
    await (update(jsLevels)..where((l) => l.id.equals(levelId))).write(
      const JsLevelsCompanion(isUnlocked: Value(true)),
    );
  }

  // ==================== TOPICS ====================

  Future<List<JsTopic>> getTopicsByLevel(String levelId) =>
      (select(jsTopics)
            ..where((t) => t.levelId.equals(levelId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  Future<JsTopic?> getTopicById(String id) =>
      (select(jsTopics)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<JsTopic>> getAllTopics() =>
      (select(jsTopics)..orderBy([(t) => OrderingTerm.asc(t.orderIndex)])).get();

  Future<int> insertTopic(JsTopicsCompanion topic) =>
      into(jsTopics).insert(topic, mode: InsertMode.insertOrReplace);

  Future<void> insertTopics(List<JsTopicsCompanion> topics) async {
    await batch((batch) {
      batch.insertAll(jsTopics, topics, mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> unlockTopic(String topicId) async {
    await (update(jsTopics)..where((t) => t.id.equals(topicId))).write(
      const JsTopicsCompanion(isUnlocked: Value(true)),
    );
  }

  Future<void> markTopicCompleted(String topicId) async {
    await (update(jsTopics)..where((t) => t.id.equals(topicId))).write(
      const JsTopicsCompanion(isCompleted: Value(true)),
    );
  }

  // ==================== LESSONS ====================

  Future<List<JsLesson>> getLessonsByTopic(String topicId) =>
      (select(jsLessons)
            ..where((l) => l.topicId.equals(topicId))
            ..orderBy([(l) => OrderingTerm.asc(l.orderIndex)]))
          .get();

  Future<JsLesson?> getLessonById(String id) =>
      (select(jsLessons)..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<List<JsLesson>> getBookmarkedLessons() =>
      (select(jsLessons)..where((l) => l.isBookmarked.equals(true))).get();

  Future<int> insertLesson(JsLessonsCompanion lesson) =>
      into(jsLessons).insert(lesson, mode: InsertMode.insertOrReplace);

  Future<void> insertLessons(List<JsLessonsCompanion> lessons) async {
    await batch((batch) {
      batch.insertAll(jsLessons, lessons, mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> markLessonCompleted(String lessonId) async {
    await (update(jsLessons)..where((l) => l.id.equals(lessonId))).write(
      JsLessonsCompanion(
        isCompleted: const Value(true),
        completedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> toggleLessonBookmark(String lessonId, bool isBookmarked) async {
    await (update(jsLessons)..where((l) => l.id.equals(lessonId))).write(
      JsLessonsCompanion(isBookmarked: Value(isBookmarked)),
    );
  }

  Future<int> getCompletedLessonsCount(String topicId) async {
    final result = await (select(jsLessons)
          ..where((l) => l.topicId.equals(topicId) & l.isCompleted.equals(true)))
        .get();
    return result.length;
  }

  // ==================== QUIZZES ====================

  Future<List<JsQuizze>> getQuizzesByLesson(String lessonId) =>
      (select(jsQuizzes)
            ..where((q) => q.lessonId.equals(lessonId))
            ..orderBy([(q) => OrderingTerm.asc(q.orderIndex)]))
          .get();

  Future<List<JsQuizze>> getQuizzesByTopic(String topicId) =>
      (select(jsQuizzes)
            ..where((q) => q.topicId.equals(topicId))
            ..orderBy([(q) => OrderingTerm.asc(q.orderIndex)]))
          .get();

  Future<int> insertQuiz(JsQuizzesCompanion quiz) =>
      into(jsQuizzes).insert(quiz, mode: InsertMode.insertOrReplace);

  Future<void> insertQuizzes(List<JsQuizzesCompanion> quizzes) async {
    await batch((batch) {
      batch.insertAll(jsQuizzes, quizzes, mode: InsertMode.insertOrReplace);
    });
  }

  // ==================== CHALLENGES ====================

  Future<List<JsChallenge>> getChallengesByTopic(String topicId) =>
      (select(jsChallenges)
            ..where((c) => c.topicId.equals(topicId))
            ..orderBy([(c) => OrderingTerm.asc(c.orderIndex)]))
          .get();

  Future<JsChallenge?> getChallengeById(String id) =>
      (select(jsChallenges)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> insertChallenge(JsChallengesCompanion challenge) =>
      into(jsChallenges).insert(challenge, mode: InsertMode.insertOrReplace);

  Future<void> insertChallenges(List<JsChallengesCompanion> challenges) async {
    await batch((batch) {
      batch.insertAll(jsChallenges, challenges, mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> markChallengeCompleted(String challengeId) async {
    await (update(jsChallenges)..where((c) => c.id.equals(challengeId))).write(
      JsChallengesCompanion(
        isCompleted: const Value(true),
        completedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==================== TOPIC PROGRESS ====================

  Future<JsTopicProgressData?> getTopicProgress(String topicId, {String userId = 'local'}) =>
      (select(jsTopicProgress)
            ..where((p) => p.topicId.equals(topicId) & p.userId.equals(userId)))
          .getSingleOrNull();

  Future<List<JsTopicProgressData>> getAllTopicProgress({String userId = 'local'}) =>
      (select(jsTopicProgress)..where((p) => p.userId.equals(userId))).get();

  Future<int> insertOrUpdateTopicProgress(JsTopicProgressCompanion progress) =>
      into(jsTopicProgress).insert(progress, mode: InsertMode.insertOrReplace);

  Future<void> updateTopicProgress({
    required String topicId,
    String userId = 'local',
  }) async {
    final topic = await getTopicById(topicId);
    if (topic == null) return;

    final completedLessons = await getCompletedLessonsCount(topicId);
    final totalLessons = topic.totalLessons;
    final percentage = totalLessons > 0 ? (completedLessons / totalLessons) * 100 : 0.0;
    final isCompleted = completedLessons >= totalLessons && totalLessons > 0;

    final existing = await getTopicProgress(topicId, userId: userId);

    await insertOrUpdateTopicProgress(JsTopicProgressCompanion(
      id: Value(existing?.id ?? '${userId}_$topicId'),
      topicId: Value(topicId),
      userId: Value(userId),
      completedLessons: Value(completedLessons),
      totalLessons: Value(totalLessons),
      completionPercentage: Value(percentage),
      isCompleted: Value(isCompleted),
      lastAccessedAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
      completedAt: isCompleted ? Value(DateTime.now()) : const Value.absent(),
    ));

    if (isCompleted) {
      await markTopicCompleted(topicId);
      await _unlockNextTopic(topicId);
    }
  }

  Future<void> _unlockNextTopic(String currentTopicId) async {
    final currentTopic = await getTopicById(currentTopicId);
    if (currentTopic == null) return;

    final nextTopics = await (select(jsTopics)
          ..where((t) => t.levelId.equals(currentTopic.levelId) & 
                         t.orderIndex.isBiggerThanValue(currentTopic.orderIndex))
          ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)])
          ..limit(1))
        .get();

    if (nextTopics.isNotEmpty) {
      await unlockTopic(nextTopics.first.id);
    } else {
      // All topics in level completed, unlock next level
      await _unlockNextLevel(currentTopic.levelId);
    }
  }

  Future<void> _unlockNextLevel(String currentLevelId) async {
    final currentLevel = await getLevelById(currentLevelId);
    if (currentLevel == null) return;

    final nextLevels = await (select(jsLevels)
          ..where((l) => l.levelNumber.isBiggerThanValue(currentLevel.levelNumber))
          ..orderBy([(l) => OrderingTerm.asc(l.levelNumber)])
          ..limit(1))
        .get();

    if (nextLevels.isNotEmpty) {
      await unlockLevel(nextLevels.first.id);
      // Unlock first topic of next level
      final firstTopics = await (select(jsTopics)
            ..where((t) => t.levelId.equals(nextLevels.first.id))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)])
            ..limit(1))
          .get();
      if (firstTopics.isNotEmpty) {
        await unlockTopic(firstTopics.first.id);
      }
    }
  }

  // ==================== USER STATS ====================

  Future<JsUserStat?> getUserStats({String userId = 'local'}) =>
      (select(jsUserStats)..where((s) => s.userId.equals(userId))).getSingleOrNull();

  Future<void> initUserStats({String userId = 'local'}) async {
    final existing = await getUserStats(userId: userId);
    if (existing == null) {
      await into(jsUserStats).insert(JsUserStatsCompanion(
        id: Value(userId),
        userId: Value(userId),
        lastActivityDate: Value(DateTime.now()),
      ));
    }
  }

  Future<void> addXp(int amount, {String userId = 'local'}) async {
    final stats = await getUserStats(userId: userId);
    if (stats == null) {
      await initUserStats(userId: userId);
      await addXp(amount, userId: userId);
      return;
    }

    final newXp = stats.totalXp + amount;
    final newLevel = _calculateLevel(newXp);
    final newRank = _calculateRank(newXp);

    await (update(jsUserStats)..where((s) => s.userId.equals(userId))).write(
      JsUserStatsCompanion(
        totalXp: Value(newXp),
        currentLevel: Value(newLevel),
        currentRank: Value(newRank),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  int _calculateLevel(int xp) {
    // Each level requires progressively more XP
    // Level 1: 0-100, Level 2: 100-300, Level 3: 300-600, etc.
    int level = 1;
    int requiredXp = 100;
    int totalRequired = 0;
    
    while (xp >= totalRequired + requiredXp) {
      totalRequired += requiredXp;
      level++;
      requiredXp = level * 100;
    }
    
    return level;
  }

  String _calculateRank(int xp) {
    if (xp >= 50000) return 'Master';
    if (xp >= 25000) return 'Expert';
    if (xp >= 10000) return 'Senior';
    if (xp >= 5000) return 'Intermediate';
    if (xp >= 1000) return 'Junior';
    return 'Beginner';
  }

  Future<void> updateStreak({String userId = 'local'}) async {
    final stats = await getUserStats(userId: userId);
    if (stats == null) {
      await initUserStats(userId: userId);
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastActivity = stats.lastActivityDate;

    int newStreak = stats.currentStreak;
    int longestStreak = stats.longestStreak;

    if (lastActivity != null) {
      final lastActivityDay = DateTime(lastActivity.year, lastActivity.month, lastActivity.day);
      final difference = today.difference(lastActivityDay).inDays;

      if (difference == 1) {
        newStreak += 1;
      } else if (difference > 1) {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }

    if (newStreak > longestStreak) {
      longestStreak = newStreak;
    }

    await (update(jsUserStats)..where((s) => s.userId.equals(userId))).write(
      JsUserStatsCompanion(
        currentStreak: Value(newStreak),
        longestStreak: Value(longestStreak),
        lastActivityDate: Value(now),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> incrementLessonsCompleted({String userId = 'local'}) async {
    final stats = await getUserStats(userId: userId);
    if (stats == null) return;

    await (update(jsUserStats)..where((s) => s.userId.equals(userId))).write(
      JsUserStatsCompanion(
        totalLessonsCompleted: Value(stats.totalLessonsCompleted + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> incrementQuizzesCompleted({String userId = 'local'}) async {
    final stats = await getUserStats(userId: userId);
    if (stats == null) return;

    await (update(jsUserStats)..where((s) => s.userId.equals(userId))).write(
      JsUserStatsCompanion(
        totalQuizzesCompleted: Value(stats.totalQuizzesCompleted + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> incrementChallengesCompleted({String userId = 'local'}) async {
    final stats = await getUserStats(userId: userId);
    if (stats == null) return;

    await (update(jsUserStats)..where((s) => s.userId.equals(userId))).write(
      JsUserStatsCompanion(
        totalChallengesCompleted: Value(stats.totalChallengesCompleted + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> addMinutesLearned(int minutes, {String userId = 'local'}) async {
    final stats = await getUserStats(userId: userId);
    if (stats == null) return;

    await (update(jsUserStats)..where((s) => s.userId.equals(userId))).write(
      JsUserStatsCompanion(
        totalMinutesLearned: Value(stats.totalMinutesLearned + minutes),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ==================== DAILY ACTIVITY ====================

  Future<JsDailyActivityData?> getTodayActivity({String userId = 'local'}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final results = await (select(jsDailyActivity)
          ..where((a) =>
              a.userId.equals(userId) &
              a.activityDate.isBiggerOrEqualValue(today) &
              a.activityDate.isSmallerThanValue(tomorrow)))
        .get();

    return results.isNotEmpty ? results.first : null;
  }

  Future<void> recordActivity({
    int lessonsCompleted = 0,
    int quizzesCompleted = 0,
    int challengesCompleted = 0,
    int xpEarned = 0,
    int minutesSpent = 0,
    String userId = 'local',
  }) async {
    final today = await getTodayActivity(userId: userId);
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    if (today == null) {
      await into(jsDailyActivity).insert(JsDailyActivityCompanion(
        id: Value('${userId}_${todayDate.toIso8601String()}'),
        userId: Value(userId),
        activityDate: Value(todayDate),
        lessonsCompleted: Value(lessonsCompleted),
        quizzesCompleted: Value(quizzesCompleted),
        challengesCompleted: Value(challengesCompleted),
        xpEarned: Value(xpEarned),
        minutesSpent: Value(minutesSpent),
        goalMet: Value(lessonsCompleted >= 1),
      ));
    } else {
      final newLessons = today.lessonsCompleted + lessonsCompleted;
      await (update(jsDailyActivity)..where((a) => a.id.equals(today.id))).write(
        JsDailyActivityCompanion(
          lessonsCompleted: Value(newLessons),
          quizzesCompleted: Value(today.quizzesCompleted + quizzesCompleted),
          challengesCompleted: Value(today.challengesCompleted + challengesCompleted),
          xpEarned: Value(today.xpEarned + xpEarned),
          minutesSpent: Value(today.minutesSpent + minutesSpent),
          goalMet: Value(newLessons >= 1),
        ),
      );
    }
  }

  Future<List<JsDailyActivityData>> getActivityHistory({
    int days = 30,
    String userId = 'local',
  }) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));

    return (select(jsDailyActivity)
          ..where((a) => a.userId.equals(userId) & a.activityDate.isBiggerOrEqualValue(startDate))
          ..orderBy([(a) => OrderingTerm.desc(a.activityDate)]))
        .get();
  }

  // ==================== QUIZ ATTEMPTS ====================

  Future<List<JsQuizAttempt>> getQuizAttempts(String lessonId, {String userId = 'local'}) =>
      (select(jsQuizAttempts)
            ..where((a) => a.lessonId.equals(lessonId) & a.userId.equals(userId))
            ..orderBy([(a) => OrderingTerm.desc(a.startedAt)]))
          .get();

  Future<JsQuizAttempt?> getBestQuizAttempt(String lessonId, {String userId = 'local'}) async {
    final attempts = await (select(jsQuizAttempts)
          ..where((a) => a.lessonId.equals(lessonId) & a.userId.equals(userId) & a.isPassed.equals(true))
          ..orderBy([(a) => OrderingTerm.desc(a.score)])
          ..limit(1))
        .get();
    return attempts.isNotEmpty ? attempts.first : null;
  }

  Future<int> insertQuizAttempt(JsQuizAttemptsCompanion attempt) =>
      into(jsQuizAttempts).insert(attempt);

  Future<void> updateQuizAttempt(String id, JsQuizAttemptsCompanion attempt) async {
    await (update(jsQuizAttempts)..where((a) => a.id.equals(id))).write(attempt);
  }

  // ==================== BOOKMARKS ====================

  Future<List<JsBookmark>> getAllBookmarks({String userId = 'local'}) =>
      (select(jsBookmarks)
            ..where((b) => b.userId.equals(userId))
            ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
          .get();

  Future<void> addBookmark(String lessonId, {String note = '', String userId = 'local'}) async {
    await into(jsBookmarks).insert(JsBookmarksCompanion(
      id: Value('${userId}_$lessonId'),
      lessonId: Value(lessonId),
      userId: Value(userId),
      note: Value(note),
    ), mode: InsertMode.insertOrReplace);
  }

  Future<void> removeBookmark(String lessonId, {String userId = 'local'}) async {
    await (delete(jsBookmarks)
          ..where((b) => b.lessonId.equals(lessonId) & b.userId.equals(userId)))
        .go();
  }

  // ==================== LESSON NOTES ====================

  Future<JsLessonNote?> getLessonNote(String lessonId, {String userId = 'local'}) =>
      (select(jsLessonNotes)
            ..where((n) => n.lessonId.equals(lessonId) & n.userId.equals(userId)))
          .getSingleOrNull();

  Future<void> saveLessonNote(String lessonId, String content, {String userId = 'local'}) async {
    await into(jsLessonNotes).insert(JsLessonNotesCompanion(
      id: Value('${userId}_$lessonId'),
      lessonId: Value(lessonId),
      userId: Value(userId),
      content: Value(content),
      updatedAt: Value(DateTime.now()),
    ), mode: InsertMode.insertOrReplace);
  }
}
