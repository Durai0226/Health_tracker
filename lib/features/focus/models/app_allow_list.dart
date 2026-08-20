import 'package:flutter/material.dart';
import '../../../core/utils/enum_json.dart';

enum AppCategory {
  productivity,
  education,
  utilities,
  health,
  communication,
  music,
  social,
  entertainment,
  other,
}

extension AppCategoryExtension on AppCategory {
  String get name {
    switch (this) {
      case AppCategory.productivity:
        return 'Productivity';
      case AppCategory.education:
        return 'Education';
      case AppCategory.utilities:
        return 'Utilities';
      case AppCategory.health:
        return 'Health';
      case AppCategory.communication:
        return 'Communication';
      case AppCategory.music:
        return 'Music';
      case AppCategory.social:
        return 'Social';
      case AppCategory.entertainment:
        return 'Entertainment';
      case AppCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case AppCategory.productivity:
        return '📊';
      case AppCategory.education:
        return '📚';
      case AppCategory.utilities:
        return '🔧';
      case AppCategory.health:
        return '💊';
      case AppCategory.communication:
        return '💬';
      case AppCategory.music:
        return '🎵';
      case AppCategory.social:
        return '👥';
      case AppCategory.entertainment:
        return '🎮';
      case AppCategory.other:
        return '📱';
    }
  }

  Color get color {
    switch (this) {
      case AppCategory.productivity:
        return const Color(0xFF2196F3);
      case AppCategory.education:
        return const Color(0xFF9C27B0);
      case AppCategory.utilities:
        return const Color(0xFF607D8B);
      case AppCategory.health:
        return const Color(0xFFE91E63);
      case AppCategory.communication:
        return const Color(0xFF00BCD4);
      case AppCategory.music:
        return const Color(0xFFFF5722);
      case AppCategory.social:
        return const Color(0xFF4CAF50);
      case AppCategory.entertainment:
        return const Color(0xFFFF9800);
      case AppCategory.other:
        return const Color(0xFF795548);
    }
  }
}

class AllowedApp {
  final String id;
  final String name;
  final String? packageName;
  final String? bundleId;
  final AppCategory category;
  final bool isAllowed;
  final DateTime addedAt;
  final String? iconUrl;

  AllowedApp({
    required this.id,
    required this.name,
    this.packageName,
    this.bundleId,
    required this.category,
    this.isAllowed = true,
    required this.addedAt,
    this.iconUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'packageName': packageName,
        'bundleId': bundleId,
        'category': category.index,
        'isAllowed': isAllowed,
        'addedAt': addedAt.toIso8601String(),
        'iconUrl': iconUrl,
      };

  factory AllowedApp.fromJson(Map<String, dynamic> json) => AllowedApp(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        packageName: json['packageName'],
        bundleId: json['bundleId'],
        category: EnumJson.at(
            AppCategory.values, json['category'], AppCategory.other),
        isAllowed: json['isAllowed'] ?? true,
        addedAt: DateTime.parse(json['addedAt']),
        iconUrl: json['iconUrl'],
      );

  AllowedApp copyWith({
    String? id,
    String? name,
    String? packageName,
    String? bundleId,
    AppCategory? category,
    bool? isAllowed,
    DateTime? addedAt,
    String? iconUrl,
  }) {
    return AllowedApp(
      id: id ?? this.id,
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      bundleId: bundleId ?? this.bundleId,
      category: category ?? this.category,
      isAllowed: isAllowed ?? this.isAllowed,
      addedAt: addedAt ?? this.addedAt,
      iconUrl: iconUrl ?? this.iconUrl,
    );
  }
}

/// The user's own list of apps that tend to pull them out of a focus session.
///
/// **It is a note to self, not an enforcement mechanism**, and the model no
/// longer pretends otherwise. It used to carry `isStrictMode`,
/// `blockNotifications`, `showWarningOnBlockedApp` and `gracePeriodSeconds`,
/// plus an `isAppAllowed(packageName)` predicate — the shape of a real blocker.
/// None of it ran: `isAppAllowed` had no production caller, nothing in the app
/// detects an app switch, and the manifest declares none of the permissions
/// blocking needs. The presets could not have matched anything even if something
/// had called it, because they were created with `packageName` and `bundleId`
/// both null.
///
/// Those five members are removed rather than left unused, because a field that
/// exists gets rendered again and a predicate that exists gets called. `fromJson`
/// ignores the old keys so existing lists still load.
class AppAllowList {
  final List<AllowedApp> apps;

  const AppAllowList({this.apps = const []});

  List<AllowedApp> get allowedApps => apps.where((a) => a.isAllowed).toList();
  List<AllowedApp> get blockedApps => apps.where((a) => !a.isAllowed).toList();

  Map<String, dynamic> toJson() => {
        'apps': apps.map((a) => a.toJson()).toList(),
      };

  factory AppAllowList.fromJson(Map<String, dynamic> json) => AppAllowList(
        apps: (json['apps'] as List?)
                ?.map((a) => AllowedApp.fromJson(Map<String, dynamic>.from(a)))
                .toList() ??
            const [],
      );

  AppAllowList copyWith({List<AllowedApp>? apps}) =>
      AppAllowList(apps: apps ?? this.apps);
}

class PresetAllowList {
  static List<AllowedApp> getProductivityApps() {
    final now = DateTime.now();
    return [
      AllowedApp(id: 'notes', name: 'Notes', category: AppCategory.productivity, addedAt: now),
      AllowedApp(id: 'calendar', name: 'Calendar', category: AppCategory.productivity, addedAt: now),
      AllowedApp(id: 'reminders', name: 'Reminders', category: AppCategory.productivity, addedAt: now),
      AllowedApp(id: 'notion', name: 'Notion', category: AppCategory.productivity, addedAt: now),
      AllowedApp(id: 'todoist', name: 'Todoist', category: AppCategory.productivity, addedAt: now),
      AllowedApp(id: 'trello', name: 'Trello', category: AppCategory.productivity, addedAt: now),
    ];
  }

  static List<AllowedApp> getEducationApps() {
    final now = DateTime.now();
    return [
      AllowedApp(id: 'duolingo', name: 'Duolingo', category: AppCategory.education, addedAt: now),
      AllowedApp(id: 'coursera', name: 'Coursera', category: AppCategory.education, addedAt: now),
      AllowedApp(id: 'khan', name: 'Khan Academy', category: AppCategory.education, addedAt: now),
      AllowedApp(id: 'quizlet', name: 'Quizlet', category: AppCategory.education, addedAt: now),
      AllowedApp(id: 'anki', name: 'Anki', category: AppCategory.education, addedAt: now),
    ];
  }

  static List<AllowedApp> getMusicApps() {
    final now = DateTime.now();
    return [
      AllowedApp(id: 'spotify', name: 'Spotify', category: AppCategory.music, addedAt: now),
      AllowedApp(id: 'apple_music', name: 'Apple Music', category: AppCategory.music, addedAt: now),
      AllowedApp(id: 'youtube_music', name: 'YouTube Music', category: AppCategory.music, addedAt: now),
    ];
  }
}
