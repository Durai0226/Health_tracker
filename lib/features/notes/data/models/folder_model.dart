import 'package:hive/hive.dart';

part 'folder_model.g.dart';

@HiveType(typeId: 101)
class FolderModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? parentId; // For nested folders

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String? color;

  @HiveField(5)
  final String? icon;

  @HiveField(6)
  final bool isSynced;

  FolderModel({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    this.color,
    this.icon,
    this.isSynced = false,
  });

  FolderModel copyWith({
    String? id,
    String? name,
    String? parentId,
    DateTime? createdAt,
    String? color,
    String? icon,
    bool? isSynced,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'createdAt': createdAt.toIso8601String(),
    'color': color,
    'icon': icon,
    'isSynced': isSynced,
  };

  factory FolderModel.fromJson(Map<String, dynamic> json) => FolderModel(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    parentId: json['parentId'],
    createdAt: DateTime.parse(json['createdAt']),
    color: json['color'],
    icon: json['icon'],
    isSynced: json['isSynced'] ?? false,
  );
}
