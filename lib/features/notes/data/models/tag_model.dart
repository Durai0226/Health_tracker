import 'package:hive/hive.dart';

part 'tag_model.g.dart';

@HiveType(typeId: 102)
class TagModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? color;

  @HiveField(3)
  final bool isSynced;

  TagModel({
    required this.id,
    required this.name,
    this.color,
    this.isSynced = false,
  });

  TagModel copyWith({
    String? id,
    String? name,
    String? color,
    bool? isSynced,
  }) {
    return TagModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'isSynced': isSynced,
  };

  factory TagModel.fromJson(Map<String, dynamic> json) => TagModel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    color: json['color'],
    isSynced: json['isSynced'] ?? false,
  );
}
