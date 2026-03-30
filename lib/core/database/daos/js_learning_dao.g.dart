// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'js_learning_dao.dart';

// ignore_for_file: type=lint
mixin _$JsLearningDaoMixin on DatabaseAccessor<AppDatabase> {
  $JsLevelsTable get jsLevels => attachedDatabase.jsLevels;
  $JsTopicsTable get jsTopics => attachedDatabase.jsTopics;
  $JsLessonsTable get jsLessons => attachedDatabase.jsLessons;
  $JsQuizzesTable get jsQuizzes => attachedDatabase.jsQuizzes;
  $JsChallengesTable get jsChallenges => attachedDatabase.jsChallenges;
  $JsTopicProgressTable get jsTopicProgress => attachedDatabase.jsTopicProgress;
  $JsUserStatsTable get jsUserStats => attachedDatabase.jsUserStats;
  $JsDailyActivityTable get jsDailyActivity => attachedDatabase.jsDailyActivity;
  $JsQuizAttemptsTable get jsQuizAttempts => attachedDatabase.jsQuizAttempts;
  $JsBookmarksTable get jsBookmarks => attachedDatabase.jsBookmarks;
  $JsLessonNotesTable get jsLessonNotes => attachedDatabase.jsLessonNotes;
  JsLearningDaoManager get managers => JsLearningDaoManager(this);
}

class JsLearningDaoManager {
  final _$JsLearningDaoMixin _db;
  JsLearningDaoManager(this._db);
  $$JsLevelsTableTableManager get jsLevels =>
      $$JsLevelsTableTableManager(_db.attachedDatabase, _db.jsLevels);
  $$JsTopicsTableTableManager get jsTopics =>
      $$JsTopicsTableTableManager(_db.attachedDatabase, _db.jsTopics);
  $$JsLessonsTableTableManager get jsLessons =>
      $$JsLessonsTableTableManager(_db.attachedDatabase, _db.jsLessons);
  $$JsQuizzesTableTableManager get jsQuizzes =>
      $$JsQuizzesTableTableManager(_db.attachedDatabase, _db.jsQuizzes);
  $$JsChallengesTableTableManager get jsChallenges =>
      $$JsChallengesTableTableManager(_db.attachedDatabase, _db.jsChallenges);
  $$JsTopicProgressTableTableManager get jsTopicProgress =>
      $$JsTopicProgressTableTableManager(
        _db.attachedDatabase,
        _db.jsTopicProgress,
      );
  $$JsUserStatsTableTableManager get jsUserStats =>
      $$JsUserStatsTableTableManager(_db.attachedDatabase, _db.jsUserStats);
  $$JsDailyActivityTableTableManager get jsDailyActivity =>
      $$JsDailyActivityTableTableManager(
        _db.attachedDatabase,
        _db.jsDailyActivity,
      );
  $$JsQuizAttemptsTableTableManager get jsQuizAttempts =>
      $$JsQuizAttemptsTableTableManager(
        _db.attachedDatabase,
        _db.jsQuizAttempts,
      );
  $$JsBookmarksTableTableManager get jsBookmarks =>
      $$JsBookmarksTableTableManager(_db.attachedDatabase, _db.jsBookmarks);
  $$JsLessonNotesTableTableManager get jsLessonNotes =>
      $$JsLessonNotesTableTableManager(_db.attachedDatabase, _db.jsLessonNotes);
}
