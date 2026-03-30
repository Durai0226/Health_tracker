/// Current Affairs Models for Exam Prep Feature
/// Supports weekly updates via Firestore sync

class CurrentAffairsItem {
  final String id;
  final String title;
  final String content;
  final String summary;
  final CurrentAffairsCategory category;
  final DateTime publishDate;
  final DateTime weekStartDate; // Start of the week this belongs to
  final int weekNumber; // Week of year
  final int year;
  final List<String> tags;
  final String? imageUrl;
  final String? source;
  final bool isImportant;
  final int viewCount;
  final List<RelatedQuestion> relatedQuestions;

  const CurrentAffairsItem({
    required this.id,
    required this.title,
    required this.content,
    required this.summary,
    required this.category,
    required this.publishDate,
    required this.weekStartDate,
    required this.weekNumber,
    required this.year,
    this.tags = const [],
    this.imageUrl,
    this.source,
    this.isImportant = false,
    this.viewCount = 0,
    this.relatedQuestions = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'summary': summary,
    'category': category.name,
    'publishDate': publishDate.toIso8601String(),
    'weekStartDate': weekStartDate.toIso8601String(),
    'weekNumber': weekNumber,
    'year': year,
    'tags': tags,
    'imageUrl': imageUrl,
    'source': source,
    'isImportant': isImportant,
    'viewCount': viewCount,
    'relatedQuestions': relatedQuestions.map((q) => q.toJson()).toList(),
  };

  factory CurrentAffairsItem.fromJson(Map<String, dynamic> json) => CurrentAffairsItem(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    summary: json['summary'] as String,
    category: CurrentAffairsCategory.values.firstWhere(
      (e) => e.name == json['category'],
      orElse: () => CurrentAffairsCategory.national,
    ),
    publishDate: DateTime.parse(json['publishDate'] as String),
    weekStartDate: DateTime.parse(json['weekStartDate'] as String),
    weekNumber: json['weekNumber'] as int,
    year: json['year'] as int,
    tags: List<String>.from(json['tags'] ?? []),
    imageUrl: json['imageUrl'] as String?,
    source: json['source'] as String?,
    isImportant: json['isImportant'] as bool? ?? false,
    viewCount: json['viewCount'] as int? ?? 0,
    relatedQuestions: (json['relatedQuestions'] as List?)
        ?.map((q) => RelatedQuestion.fromJson(q))
        .toList() ?? [],
  );

  CurrentAffairsItem copyWith({
    String? id,
    String? title,
    String? content,
    String? summary,
    CurrentAffairsCategory? category,
    DateTime? publishDate,
    DateTime? weekStartDate,
    int? weekNumber,
    int? year,
    List<String>? tags,
    String? imageUrl,
    String? source,
    bool? isImportant,
    int? viewCount,
    List<RelatedQuestion>? relatedQuestions,
  }) {
    return CurrentAffairsItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      category: category ?? this.category,
      publishDate: publishDate ?? this.publishDate,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      weekNumber: weekNumber ?? this.weekNumber,
      year: year ?? this.year,
      tags: tags ?? this.tags,
      imageUrl: imageUrl ?? this.imageUrl,
      source: source ?? this.source,
      isImportant: isImportant ?? this.isImportant,
      viewCount: viewCount ?? this.viewCount,
      relatedQuestions: relatedQuestions ?? this.relatedQuestions,
    );
  }
}

enum CurrentAffairsCategory {
  national,
  international,
  economy,
  banking,
  sports,
  science,
  awards,
  appointments,
  obituary,
  schemes,
  summits,
  reports,
  defense,
  environment,
}

extension CurrentAffairsCategoryExtension on CurrentAffairsCategory {
  String get displayName {
    switch (this) {
      case CurrentAffairsCategory.national:
        return 'National';
      case CurrentAffairsCategory.international:
        return 'International';
      case CurrentAffairsCategory.economy:
        return 'Economy & Finance';
      case CurrentAffairsCategory.banking:
        return 'Banking & Finance';
      case CurrentAffairsCategory.sports:
        return 'Sports';
      case CurrentAffairsCategory.science:
        return 'Science & Tech';
      case CurrentAffairsCategory.awards:
        return 'Awards & Honours';
      case CurrentAffairsCategory.appointments:
        return 'Appointments';
      case CurrentAffairsCategory.obituary:
        return 'Obituary';
      case CurrentAffairsCategory.schemes:
        return 'Govt. Schemes';
      case CurrentAffairsCategory.summits:
        return 'Summits & Conferences';
      case CurrentAffairsCategory.reports:
        return 'Reports & Indices';
      case CurrentAffairsCategory.defense:
        return 'Defense';
      case CurrentAffairsCategory.environment:
        return 'Environment';
    }
  }

  String get icon {
    switch (this) {
      case CurrentAffairsCategory.national:
        return '🇮🇳';
      case CurrentAffairsCategory.international:
        return '🌍';
      case CurrentAffairsCategory.economy:
        return '📈';
      case CurrentAffairsCategory.banking:
        return '🏦';
      case CurrentAffairsCategory.sports:
        return '⚽';
      case CurrentAffairsCategory.science:
        return '🔬';
      case CurrentAffairsCategory.awards:
        return '🏆';
      case CurrentAffairsCategory.appointments:
        return '👔';
      case CurrentAffairsCategory.obituary:
        return '🕯️';
      case CurrentAffairsCategory.schemes:
        return '📋';
      case CurrentAffairsCategory.summits:
        return '🤝';
      case CurrentAffairsCategory.reports:
        return '📊';
      case CurrentAffairsCategory.defense:
        return '🛡️';
      case CurrentAffairsCategory.environment:
        return '🌱';
    }
  }
}

class RelatedQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const RelatedQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
  };

  factory RelatedQuestion.fromJson(Map<String, dynamic> json) => RelatedQuestion(
    question: json['question'] as String,
    options: List<String>.from(json['options']),
    correctIndex: json['correctIndex'] as int,
    explanation: json['explanation'] as String,
  );
}

/// Weekly Digest for Current Affairs
class WeeklyDigest {
  final String id;
  final int weekNumber;
  final int year;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final String title;
  final String summary;
  final int totalItems;
  final Map<CurrentAffairsCategory, int> categoryCount;
  final List<String> highlights;
  final bool isDownloaded;
  final DateTime? lastSyncedAt;

  const WeeklyDigest({
    required this.id,
    required this.weekNumber,
    required this.year,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.title,
    required this.summary,
    required this.totalItems,
    this.categoryCount = const {},
    this.highlights = const [],
    this.isDownloaded = false,
    this.lastSyncedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'weekNumber': weekNumber,
    'year': year,
    'weekStartDate': weekStartDate.toIso8601String(),
    'weekEndDate': weekEndDate.toIso8601String(),
    'title': title,
    'summary': summary,
    'totalItems': totalItems,
    'categoryCount': categoryCount.map((k, v) => MapEntry(k.name, v)),
    'highlights': highlights,
    'isDownloaded': isDownloaded,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  factory WeeklyDigest.fromJson(Map<String, dynamic> json) => WeeklyDigest(
    id: json['id'] as String,
    weekNumber: json['weekNumber'] as int,
    year: json['year'] as int,
    weekStartDate: DateTime.parse(json['weekStartDate'] as String),
    weekEndDate: DateTime.parse(json['weekEndDate'] as String),
    title: json['title'] as String,
    summary: json['summary'] as String,
    totalItems: json['totalItems'] as int,
    categoryCount: (json['categoryCount'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(
        CurrentAffairsCategory.values.firstWhere((e) => e.name == k),
        v as int,
      ),
    ) ?? {},
    highlights: List<String>.from(json['highlights'] ?? []),
    isDownloaded: json['isDownloaded'] as bool? ?? false,
    lastSyncedAt: json['lastSyncedAt'] != null
        ? DateTime.parse(json['lastSyncedAt'] as String)
        : null,
  );

  String get formattedDateRange {
    final startMonth = _monthName(weekStartDate.month);
    final endMonth = _monthName(weekEndDate.month);
    
    if (startMonth == endMonth) {
      return '${weekStartDate.day} - ${weekEndDate.day} $startMonth $year';
    }
    return '${weekStartDate.day} $startMonth - ${weekEndDate.day} $endMonth $year';
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

/// Monthly Capsule for Current Affairs
class MonthlyCapsule {
  final String id;
  final int month;
  final int year;
  final String title;
  final int totalItems;
  final List<String> weekIds;
  final String? pdfUrl;
  final bool isDownloaded;

  const MonthlyCapsule({
    required this.id,
    required this.month,
    required this.year,
    required this.title,
    required this.totalItems,
    this.weekIds = const [],
    this.pdfUrl,
    this.isDownloaded = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'month': month,
    'year': year,
    'title': title,
    'totalItems': totalItems,
    'weekIds': weekIds,
    'pdfUrl': pdfUrl,
    'isDownloaded': isDownloaded,
  };

  factory MonthlyCapsule.fromJson(Map<String, dynamic> json) => MonthlyCapsule(
    id: json['id'] as String,
    month: json['month'] as int,
    year: json['year'] as int,
    title: json['title'] as String,
    totalItems: json['totalItems'] as int,
    weekIds: List<String>.from(json['weekIds'] ?? []),
    pdfUrl: json['pdfUrl'] as String?,
    isDownloaded: json['isDownloaded'] as bool? ?? false,
  );

  String get monthName {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }
}

/// Helper class for week calculations
class WeekHelper {
  static int getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDiff = date.difference(firstDayOfYear).inDays;
    return ((daysDiff + firstDayOfYear.weekday) / 7).ceil();
  }

  static DateTime getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - weekday + 1);
  }

  static DateTime getWeekEnd(DateTime date) {
    final weekStart = getWeekStart(date);
    return weekStart.add(const Duration(days: 6));
  }

  static List<WeekInfo> getWeeksInMonth(int year, int month) {
    final weeks = <WeekInfo>[];
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    
    var currentDay = firstDay;
    while (currentDay.isBefore(lastDay) || currentDay.isAtSameMomentAs(lastDay)) {
      final weekNumber = getWeekNumber(currentDay);
      final weekStart = getWeekStart(currentDay);
      final weekEnd = getWeekEnd(currentDay);
      
      if (weeks.isEmpty || weeks.last.weekNumber != weekNumber) {
        weeks.add(WeekInfo(
          weekNumber: weekNumber,
          year: year,
          startDate: weekStart,
          endDate: weekEnd,
        ));
      }
      
      currentDay = currentDay.add(const Duration(days: 7));
    }
    
    return weeks;
  }
}

class WeekInfo {
  final int weekNumber;
  final int year;
  final DateTime startDate;
  final DateTime endDate;

  const WeekInfo({
    required this.weekNumber,
    required this.year,
    required this.startDate,
    required this.endDate,
  });
}

/// Static sample current affairs data (can be replaced by Firestore data)
class SampleCurrentAffairs {
  static List<CurrentAffairsItem> getSampleItems() {
    final now = DateTime.now();
    final weekStart = WeekHelper.getWeekStart(now);
    final weekNumber = WeekHelper.getWeekNumber(now);
    
    return [
      CurrentAffairsItem(
        id: 'ca_001',
        title: 'RBI Monetary Policy Review',
        content: 'The Reserve Bank of India has kept the repo rate unchanged at 6.5% in its latest monetary policy review meeting...',
        summary: 'RBI keeps repo rate unchanged at 6.5%',
        category: CurrentAffairsCategory.banking,
        publishDate: now.subtract(const Duration(days: 1)),
        weekStartDate: weekStart,
        weekNumber: weekNumber,
        year: now.year,
        tags: ['RBI', 'Monetary Policy', 'Repo Rate'],
        isImportant: true,
        relatedQuestions: [
          const RelatedQuestion(
            question: 'What is the current repo rate as per RBI?',
            options: ['6.5%', '6.25%', '6.75%', '7%'],
            correctIndex: 0,
            explanation: 'RBI has kept the repo rate unchanged at 6.5%.',
          ),
        ],
      ),
      CurrentAffairsItem(
        id: 'ca_002',
        title: 'India\'s GDP Growth Rate',
        content: 'India has recorded a GDP growth rate of 8.2% in the latest quarter, making it one of the fastest growing major economies...',
        summary: 'India records 8.2% GDP growth',
        category: CurrentAffairsCategory.economy,
        publishDate: now.subtract(const Duration(days: 2)),
        weekStartDate: weekStart,
        weekNumber: weekNumber,
        year: now.year,
        tags: ['GDP', 'Economy', 'Growth'],
        isImportant: true,
      ),
      CurrentAffairsItem(
        id: 'ca_003',
        title: 'New Space Mission Announcement',
        content: 'ISRO has announced plans for a new space mission targeting the study of gravitational waves...',
        summary: 'ISRO announces new space mission',
        category: CurrentAffairsCategory.science,
        publishDate: now.subtract(const Duration(days: 3)),
        weekStartDate: weekStart,
        weekNumber: weekNumber,
        year: now.year,
        tags: ['ISRO', 'Space', 'Science'],
      ),
    ];
  }
}
