import 'package:hive/hive.dart';

part 'note_version_model.g.dart';

@HiveType(typeId: 103)
class NoteVersionModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String noteId;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime createdAt;

  NoteVersionModel({
    required this.id,
    required this.noteId,
    required this.content,
    required this.createdAt,
  });
}
