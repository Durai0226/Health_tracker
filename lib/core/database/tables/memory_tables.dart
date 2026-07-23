import 'package:drift/drift.dart';

/// Durable, user-curated assistant "memories" (ChatGPT/Oura pattern). Created
/// ONLY from explicit, confirmed user statements — never auto-extracted from
/// health data. Sensitive: kept local, excluded from cloud sync/backup, wiped
/// by "Delete all data". `active=false` supersedes an old same-kind memory so
/// contradictions can't accumulate.
@DataClassName('AssistantMemoryRow')
class AssistantMemories extends Table {
  TextColumn get id => text()();
  TextColumn get content => text()(); // the durable fact, plain language
  TextColumn get kind =>
      text().withDefault(const Constant('fact'))(); // goal | preference | fact
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get source => text().withDefault(const Constant('user'))();

  @override
  Set<Column> get primaryKey => {id};
}
