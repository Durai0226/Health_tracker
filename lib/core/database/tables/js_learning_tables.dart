import 'package:drift/drift.dart';

/// JavaScript Learning Levels/Modules
class JsLevels extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // e.g., "JavaScript Foundations"
  IntColumn get levelNumber => integer()(); // 1-6
  TextColumn get description => text()();
  TextColumn get icon => text().withDefault(const Constant('school'))();
  TextColumn get color => text().withDefault(const Constant('#F7DF1E'))();
  IntColumn get totalTopics => integer().withDefault(const Constant(0))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  BoolColumn get isUnlocked => boolean().withDefault(const Constant(false))();
  IntColumn get requiredXpToUnlock => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Topics within each level
class JsTopics extends Table {
  TextColumn get id => text()();
  TextColumn get levelId => text()();
  TextColumn get title => text()(); // e.g., "Variables & Data Types"
  TextColumn get subtitle => text().withDefault(const Constant(''))();
  TextColumn get description => text()();
  TextColumn get icon => text().withDefault(const Constant('code'))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  IntColumn get totalLessons => integer().withDefault(const Constant(0))();
  IntColumn get estimatedMinutes => integer().withDefault(const Constant(15))();
  TextColumn get difficulty => text().withDefault(const Constant('beginner'))();
  BoolColumn get isUnlocked => boolean().withDefault(const Constant(false))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get xpReward => integer().withDefault(const Constant(50))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Individual lessons within topics
class JsLessons extends Table {
  TextColumn get id => text()();
  TextColumn get topicId => text()();
  TextColumn get title => text()();
  TextColumn get simpleExplanation => text()(); // Easy to understand explanation
  TextColumn get detailedContent => text()(); // Full content in markdown
  TextColumn get codeExample => text().withDefault(const Constant(''))();
  TextColumn get realWorldExample => text().withDefault(const Constant(''))();
  TextColumn get commonMistakes => text().withDefault(const Constant(''))(); // JSON array
  TextColumn get interviewTips => text().withDefault(const Constant(''))();
  TextColumn get visualDiagramUrl => text().withDefault(const Constant(''))();
  TextColumn get animationType => text().withDefault(const Constant(''))(); // call_stack, closure, event_loop, etc.
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  IntColumn get estimatedMinutes => integer().withDefault(const Constant(5))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isBookmarked => boolean().withDefault(const Constant(false))();
  IntColumn get xpReward => integer().withDefault(const Constant(25))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Quiz questions for each lesson
class JsQuizzes extends Table {
  TextColumn get id => text()();
  TextColumn get lessonId => text()();
  TextColumn get topicId => text()();
  TextColumn get question => text()();
  TextColumn get questionType => text().withDefault(const Constant('multiple_choice'))(); // multiple_choice, true_false, fill_blank, code_output
  TextColumn get options => text()(); // JSON array of options
  TextColumn get correctAnswer => text()();
  TextColumn get explanation => text().withDefault(const Constant(''))();
  TextColumn get codeSnippet => text().withDefault(const Constant(''))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  TextColumn get difficulty => text().withDefault(const Constant('easy'))();
  IntColumn get xpReward => integer().withDefault(const Constant(10))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Code challenges for hands-on practice
class JsChallenges extends Table {
  TextColumn get id => text()();
  TextColumn get topicId => text()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get starterCode => text()();
  TextColumn get solutionCode => text()();
  TextColumn get testCases => text()(); // JSON array of test cases
  TextColumn get hints => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get difficulty => text().withDefault(const Constant('easy'))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  IntColumn get xpReward => integer().withDefault(const Constant(50))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// User progress per topic
class JsTopicProgress extends Table {
  TextColumn get id => text()();
  TextColumn get topicId => text()();
  TextColumn get userId => text().withDefault(const Constant('local'))();
  IntColumn get completedLessons => integer().withDefault(const Constant(0))();
  IntColumn get totalLessons => integer().withDefault(const Constant(0))();
  IntColumn get quizScore => integer().withDefault(const Constant(0))();
  IntColumn get quizAttempts => integer().withDefault(const Constant(0))();
  RealColumn get completionPercentage => real().withDefault(const Constant(0.0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get xpEarned => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAccessedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// User overall stats for JS learning
class JsUserStats extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant('local'))();
  IntColumn get totalXp => integer().withDefault(const Constant(0))();
  IntColumn get currentLevel => integer().withDefault(const Constant(1))();
  TextColumn get currentRank => text().withDefault(const Constant('Beginner'))(); // Beginner, Junior, Intermediate, Senior, Expert, Master
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  IntColumn get totalLessonsCompleted => integer().withDefault(const Constant(0))();
  IntColumn get totalQuizzesCompleted => integer().withDefault(const Constant(0))();
  IntColumn get totalChallengesCompleted => integer().withDefault(const Constant(0))();
  IntColumn get totalTopicsCompleted => integer().withDefault(const Constant(0))();
  IntColumn get totalLevelsCompleted => integer().withDefault(const Constant(0))();
  IntColumn get totalMinutesLearned => integer().withDefault(const Constant(0))();
  TextColumn get badges => text().withDefault(const Constant('[]'))(); // JSON array of earned badges
  TextColumn get achievements => text().withDefault(const Constant('[]'))(); // JSON array
  DateTimeColumn get lastActivityDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Daily learning activity for streaks
class JsDailyActivity extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant('local'))();
  DateTimeColumn get activityDate => dateTime()();
  IntColumn get lessonsCompleted => integer().withDefault(const Constant(0))();
  IntColumn get quizzesCompleted => integer().withDefault(const Constant(0))();
  IntColumn get challengesCompleted => integer().withDefault(const Constant(0))();
  IntColumn get xpEarned => integer().withDefault(const Constant(0))();
  IntColumn get minutesSpent => integer().withDefault(const Constant(0))();
  BoolColumn get goalMet => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Quiz attempts tracking
class JsQuizAttempts extends Table {
  TextColumn get id => text()();
  TextColumn get lessonId => text()();
  TextColumn get userId => text().withDefault(const Constant('local'))();
  IntColumn get totalQuestions => integer()();
  IntColumn get correctAnswers => integer().withDefault(const Constant(0))();
  IntColumn get score => integer().withDefault(const Constant(0))();
  IntColumn get timeSpentSeconds => integer().withDefault(const Constant(0))();
  TextColumn get answersJson => text().withDefault(const Constant('{}'))();
  BoolColumn get isPassed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bookmarked lessons for quick access
class JsBookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get lessonId => text()();
  TextColumn get userId => text().withDefault(const Constant('local'))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// User notes on lessons
class JsLessonNotes extends Table {
  TextColumn get id => text()();
  TextColumn get lessonId => text()();
  TextColumn get userId => text().withDefault(const Constant('local'))();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
