import 'reminder_escalation.dart';

// Re-exported so a consumer needs one import for the whole reminder vocabulary,
// the way RepeatType / ReminderPriority / ReminderOutcome already work.
export 'reminder_escalation.dart';


enum RepeatType {
  none,
  daily,
  weekly,
  weekdays,
  weekends,
  custom,
}

/// What became of one scheduled occurrence of a reminder.
///
/// Stored by `.name`, never by index: these rows are history, and reordering an
/// enum must not silently reinterpret what already happened.
enum ReminderOutcome {
  /// Due, not yet resolved. The state every occurrence starts in.
  pending,

  /// The user acted on it.
  done,

  /// The user explicitly declined this one occurrence. Distinct from [missed] —
  /// a deliberate skip is not a failure, and lumping them together would make
  /// adherence punish honesty.
  skipped,

  /// Never resolved, and its window has closed. Written by the sweep, not by the
  /// user. This is the denominator: without it a user who never opens the app
  /// shows perfect adherence forever.
  missed;

  static ReminderOutcome fromName(String? name) {
    for (final v in ReminderOutcome.values) {
      if (v.name == name) return v;
    }
    return ReminderOutcome.pending;
  }

  /// Whether this occurrence is settled. A pending one may still become
  /// anything; the others are final.
  bool get isResolved => this != ReminderOutcome.pending;
}

enum ReminderPriority {
  low,
  medium,
  high,
}

class Reminder {
  final String id;
  final String title;
  final String body;
  final DateTime scheduledTime;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final RepeatType repeatType;
  final List<int>? customDays;
  final int? snoozeDuration; // Minutes
  final String? sound;
  final ReminderPriority priority;
  final String? categoryId;
  final String? note;
  final String? imagePath;
  final String? noteId;

  /// The OS notification id this reminder is armed under, allocated from the
  /// reserved generic-reminder block. Null for rows written before schema v16;
  /// use [notificationSlot], which falls back to the legacy derivation so an
  /// already-armed alarm stays cancellable.
  final int? notificationId;

  /// An RFC 5545 `RRULE:` string when the repeat is richer than [repeatType] can
  /// express. Null means "use [repeatType]".
  final String? recurrenceRule;

  /// Stop repeating after this instant. Null means forever.
  final DateTime? endsAt;

  /// Stop after this many occurrences. Null means unlimited.
  final int? occurrenceLimit;

  /// Temporarily stopped without being deleted.
  final bool isPaused;

  /// How hard this reminder pushes when it is ignored. See [ReminderEscalation].
  final ReminderEscalation escalation;

  Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isSynced = false,
    this.repeatType = RepeatType.none,
    this.customDays,
    this.snoozeDuration,
    this.sound = 'default',
    this.priority = ReminderPriority.medium,
    this.categoryId,
    this.note,
    this.imagePath,
    this.noteId,
    this.notificationId,
    this.recurrenceRule,
    this.endsAt,
    this.occurrenceLimit,
    this.isPaused = false,
    this.escalation = ReminderEscalation.standard,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Reminder copyWith({
    String? title,
    String? body,
    DateTime? scheduledTime,
    bool? isCompleted,
    bool? isSynced,
    RepeatType? repeatType,
    List<int>? customDays,
    int? snoozeDuration,
    String? sound,
    ReminderPriority? priority,
    String? categoryId,
    String? note,
    String? imagePath,
    String? noteId,
    int? notificationId,
    String? recurrenceRule,
    DateTime? endsAt,
    int? occurrenceLimit,
    bool? isPaused,
    ReminderEscalation? escalation,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isSynced: isSynced ?? this.isSynced,
      repeatType: repeatType ?? this.repeatType,
      customDays: customDays ?? this.customDays,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
      sound: sound ?? this.sound,
      priority: priority ?? this.priority,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      imagePath: imagePath ?? this.imagePath,
      noteId: noteId ?? this.noteId,
      notificationId: notificationId ?? this.notificationId,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      endsAt: endsAt ?? this.endsAt,
      occurrenceLimit: occurrenceLimit ?? this.occurrenceLimit,
      isPaused: isPaused ?? this.isPaused,
      escalation: escalation ?? this.escalation,
    );
  }

  /// The id to schedule and cancel under.
  ///
  /// Prefers the allocated, reserved [notificationId]. Falls back to the legacy
  /// `id.hashCode & 0x7FFFFFFF` for rows that predate schema v16 — not because
  /// that derivation is acceptable (it is unreserved and can collide with any
  /// other family's block) but because those rows' alarms are already armed under
  /// it, and cancelling them requires reproducing it. Every save allocates a real
  /// id, so this fallback drains as reminders are touched.
  int get notificationSlot => notificationId ?? legacyNotificationId;

  /// The pre-v16 derivation. Only for cancelling what it already armed.
  int get legacyNotificationId => id.hashCode & 0x7FFFFFFF;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'repeatType': repeatType.toString().split('.').last,
      'customDays': customDays,
      'snoozeDuration': snoozeDuration,
      'sound': sound,
      'priority': priority.toString().split('.').last,
      'categoryId': categoryId,
      'note': note,
      'imagePath': imagePath,
      'noteId': noteId,
      'notificationId': notificationId,
      'recurrenceRule': recurrenceRule,
      'endsAt': endsAt?.toIso8601String(),
      'occurrenceLimit': occurrenceLimit,
      'isPaused': isPaused,
      'escalation': escalation.name,
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      scheduledTime: DateTime.parse(json['scheduledTime']),
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isSynced: true, // Assuming data from JSON (Firestore) is synced
      repeatType: json['repeatType'] != null
          ? RepeatType.values.firstWhere(
              (e) => e.toString().split('.').last == json['repeatType'],
              orElse: () => RepeatType.none,
            )
          : RepeatType.none,
      customDays: json['customDays'] != null
          ? List<int>.from(json['customDays'])
          : null,
      snoozeDuration: json['snoozeDuration'],
      sound: json['sound'] ?? 'default',
      priority: json['priority'] != null
          ? ReminderPriority.values.firstWhere(
              (e) => e.toString().split('.').last == json['priority'],
              orElse: () => ReminderPriority.medium,
            )
          : ReminderPriority.medium,
      categoryId: json['categoryId'],
      note: json['note'],
      imagePath: json['imagePath'],
      noteId: json['noteId'],
      notificationId: (json['notificationId'] as num?)?.toInt(),
      recurrenceRule: json['recurrenceRule'] as String?,
      endsAt: json['endsAt'] != null
          ? DateTime.tryParse(json['endsAt'].toString())
          : null,
      occurrenceLimit: (json['occurrenceLimit'] as num?)?.toInt(),
      isPaused: json['isPaused'] == true,
      escalation: ReminderEscalation.fromName(json['escalation'] as String?),
    );
  }
}
