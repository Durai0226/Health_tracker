import 'package:flutter/material.dart';

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
        category: AppCategory.values[json['category'] ?? 0],
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

class AppAllowList {
  final List<AllowedApp> apps;
  final bool isStrictMode;
  final bool blockNotifications;
  final bool showWarningOnBlockedApp;
  final int gracePeriodSeconds;

  const AppAllowList({
    this.apps = const [],
    this.isStrictMode = false,
    this.blockNotifications = true,
    this.showWarningOnBlockedApp = true,
    this.gracePeriodSeconds = 10,
  });

  List<AllowedApp> get allowedApps => apps.where((a) => a.isAllowed).toList();
  List<AllowedApp> get blockedApps => apps.where((a) => !a.isAllowed).toList();

  bool isAppAllowed(String packageName) {
    final app = apps.firstWhere(
      (a) => a.packageName == packageName || a.bundleId == packageName,
      orElse: () => AllowedApp(
        id: '',
        name: '',
        category: AppCategory.other,
        addedAt: DateTime.now(),
        isAllowed: !isStrictMode,
      ),
    );
    return app.isAllowed;
  }

  Map<String, dynamic> toJson() => {
        'apps': apps.map((a) => a.toJson()).toList(),
        'isStrictMode': isStrictMode,
        'blockNotifications': blockNotifications,
        'showWarningOnBlockedApp': showWarningOnBlockedApp,
        'gracePeriodSeconds': gracePeriodSeconds,
      };

  factory AppAllowList.fromJson(Map<String, dynamic> json) => AppAllowList(
        apps: (json['apps'] as List?)
                ?.map((a) => AllowedApp.fromJson(Map<String, dynamic>.from(a)))
                .toList() ??
            [],
        isStrictMode: json['isStrictMode'] ?? false,
        blockNotifications: json['blockNotifications'] ?? true,
        showWarningOnBlockedApp: json['showWarningOnBlockedApp'] ?? true,
        gracePeriodSeconds: json['gracePeriodSeconds'] ?? 10,
      );

  AppAllowList copyWith({
    List<AllowedApp>? apps,
    bool? isStrictMode,
    bool? blockNotifications,
    bool? showWarningOnBlockedApp,
    int? gracePeriodSeconds,
  }) {
    return AppAllowList(
      apps: apps ?? this.apps,
      isStrictMode: isStrictMode ?? this.isStrictMode,
      blockNotifications: blockNotifications ?? this.blockNotifications,
      showWarningOnBlockedApp: showWarningOnBlockedApp ?? this.showWarningOnBlockedApp,
      gracePeriodSeconds: gracePeriodSeconds ?? this.gracePeriodSeconds,
    );
  }
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
