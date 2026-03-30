import 'package:cloud_firestore/cloud_firestore.dart';
import 'mood_type.dart';

/// Weather data for mood entry
class MoodWeather {
  final String condition; // sunny, cloudy, rainy, etc.
  final double? temperature;
  final String? iconCode;

  const MoodWeather({
    required this.condition,
    this.temperature,
    this.iconCode,
  });

  Map<String, dynamic> toJson() => {
    'condition': condition,
    'temperature': temperature,
    'iconCode': iconCode,
  };

  factory MoodWeather.fromJson(Map<String, dynamic> json) => MoodWeather(
    condition: json['condition'] as String? ?? 'unknown',
    temperature: (json['temperature'] as num?)?.toDouble(),
    iconCode: json['iconCode'] as String?,
  );
}

/// Location data for mood entry
class MoodLocation {
  final String? name;
  final double? latitude;
  final double? longitude;

  const MoodLocation({
    this.name,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory MoodLocation.fromJson(Map<String, dynamic> json) => MoodLocation(
    name: json['name'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );
}

/// Mood entry model for storing daily mood records
class MoodEntry {
  final String id;
  final MoodType mood;
  final int intensity; // 1-5 scale
  final String? note;
  final List<ActivityType> activities;
  final DateTime timestamp;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? userId;
  
  // Enhanced fields from Behance design
  final List<String> photos; // Photo attachment URLs
  final MoodWeather? weather; // Weather at time of entry
  final MoodLocation? location; // Location at time of entry
  final String? quote; // Daily affirmation/quote

  MoodEntry({
    required this.id,
    required this.mood,
    required this.intensity,
    this.note,
    this.activities = const [],
    required this.timestamp,
    DateTime? createdAt,
    this.updatedAt,
    this.userId,
    this.photos = const [],
    this.weather,
    this.location,
    this.quote,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a new mood entry with generated ID
  factory MoodEntry.create({
    required MoodType mood,
    required int intensity,
    String? note,
    List<ActivityType>? activities,
    DateTime? timestamp,
    String? userId,
    List<String>? photos,
    MoodWeather? weather,
    MoodLocation? location,
    String? quote,
  }) {
    final now = DateTime.now();
    return MoodEntry(
      id: '${now.millisecondsSinceEpoch}_${mood.value}',
      mood: mood,
      intensity: intensity.clamp(1, 5),
      note: note,
      activities: activities ?? [],
      timestamp: timestamp ?? now,
      createdAt: now,
      userId: userId,
      photos: photos ?? [],
      weather: weather,
      location: location,
      quote: quote,
    );
  }

  /// Copy with updated fields
  MoodEntry copyWith({
    String? id,
    MoodType? mood,
    int? intensity,
    String? note,
    List<ActivityType>? activities,
    DateTime? timestamp,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    List<String>? photos,
    MoodWeather? weather,
    MoodLocation? location,
    String? quote,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      mood: mood ?? this.mood,
      intensity: intensity ?? this.intensity,
      note: note ?? this.note,
      activities: activities ?? this.activities,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      userId: userId ?? this.userId,
      photos: photos ?? this.photos,
      weather: weather ?? this.weather,
      location: location ?? this.location,
      quote: quote ?? this.quote,
    );
  }

  /// Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mood': mood.value,
      'intensity': intensity,
      'note': note,
      'activities': activities.map((a) => a.value).toList(),
      'timestamp': timestamp.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'userId': userId,
      'photos': photos,
      'weather': weather?.toJson(),
      'location': location?.toJson(),
      'quote': quote,
    };
  }

  /// Create from JSON (local storage)
  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      id: json['id'] as String,
      mood: MoodType.fromString(json['mood'] as String),
      intensity: (json['intensity'] as num?)?.toInt() ?? 3,
      note: json['note'] as String?,
      activities: (json['activities'] as List<dynamic>?)
              ?.map((a) => ActivityType.fromString(a as String))
              .toList() ??
          [],
      timestamp: DateTime.parse(json['timestamp'] as String),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      userId: json['userId'] as String?,
      photos: (json['photos'] as List<dynamic>?)?.cast<String>() ?? [],
      weather: json['weather'] != null
          ? MoodWeather.fromJson(json['weather'] as Map<String, dynamic>)
          : null,
      location: json['location'] != null
          ? MoodLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      quote: json['quote'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'mood': mood.value,
      'intensity': intensity,
      'note': note,
      'activities': activities.map((a) => a.value).toList(),
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'userId': userId,
      'photos': photos,
      'weather': weather?.toJson(),
      'location': location?.toJson(),
      'quote': quote,
    };
  }

  /// Create from Firestore document
  factory MoodEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MoodEntry(
      id: doc.id,
      mood: MoodType.fromString(data['mood'] as String? ?? 'neutral'),
      intensity: (data['intensity'] as num?)?.toInt() ?? 3,
      note: data['note'] as String?,
      activities: (data['activities'] as List<dynamic>?)
              ?.map((a) => ActivityType.fromString(a as String))
              .toList() ??
          [],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      userId: data['userId'] as String?,
      photos: (data['photos'] as List<dynamic>?)?.cast<String>() ?? [],
      weather: data['weather'] != null
          ? MoodWeather.fromJson(data['weather'] as Map<String, dynamic>)
          : null,
      location: data['location'] != null
          ? MoodLocation.fromJson(data['location'] as Map<String, dynamic>)
          : null,
      quote: data['quote'] as String?,
    );
  }

  /// Get date key for grouping (YYYY-MM-DD)
  String get dateKey {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
  }

  /// Get formatted time
  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Get formatted date
  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[timestamp.month - 1]} ${timestamp.day}, ${timestamp.year}';
  }

  /// Check if entry is from today
  bool get isToday {
    final now = DateTime.now();
    return timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
  }

  /// Check if entry is from this week
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return timestamp.isAfter(startOfWeek) && timestamp.isBefore(endOfWeek);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MoodEntry(id: $id, mood: ${mood.label}, intensity: $intensity, date: $formattedDate)';
  }
}
