import 'dart:convert';

/// Character customization part type
enum CharacterPart {
  head,
  top,
  bottom,
}

/// Character model for avatar customization
class HabitCharacter {
  final String id;
  final int headIndex;
  final int topIndex;
  final int bottomIndex;
  final String? name;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HabitCharacter({
    required this.id,
    this.headIndex = 0,
    this.topIndex = 0,
    this.bottomIndex = 0,
    this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Available head styles count
  static const int headStylesCount = 8;
  
  /// Available top/clothing styles count
  static const int topStylesCount = 10;
  
  /// Available bottom/clothing styles count
  static const int bottomStylesCount = 8;

  /// Get asset path for head
  String get headAsset => 'assets/images/character/head_$headIndex.png';
  
  /// Get asset path for top
  String get topAsset => 'assets/images/character/top_$topIndex.png';
  
  /// Get asset path for bottom
  String get bottomAsset => 'assets/images/character/bottom_$bottomIndex.png';

  HabitCharacter copyWith({
    String? id,
    int? headIndex,
    int? topIndex,
    int? bottomIndex,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HabitCharacter(
      id: id ?? this.id,
      headIndex: headIndex ?? this.headIndex,
      topIndex: topIndex ?? this.topIndex,
      bottomIndex: bottomIndex ?? this.bottomIndex,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'headIndex': headIndex,
      'topIndex': topIndex,
      'bottomIndex': bottomIndex,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HabitCharacter.fromJson(Map<String, dynamic> json) {
    return HabitCharacter(
      id: json['id'] as String,
      headIndex: json['headIndex'] as int? ?? 0,
      topIndex: json['topIndex'] as int? ?? 0,
      bottomIndex: json['bottomIndex'] as int? ?? 0,
      name: json['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory HabitCharacter.fromJsonString(String jsonString) {
    return HabitCharacter.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// Create default character
  factory HabitCharacter.defaultCharacter() {
    final now = DateTime.now();
    return HabitCharacter(
      id: 'default',
      headIndex: 0,
      topIndex: 0,
      bottomIndex: 0,
      createdAt: now,
      updatedAt: now,
    );
  }
}
