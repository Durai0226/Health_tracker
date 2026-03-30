/// Represents an audio clip linked to a page
/// Supports audio-synced handwriting playback like Livescribe
class AudioClipModel {
  final String id;
  final String pageId;
  final String filePath;
  final int startTimeMs; // When recording started relative to page creation
  final int durationSeconds;
  final List<String> linkedStrokeIds; // Strokes drawn during this recording
  final DateTime createdAt;
  final bool isSynced;
  final String? transcript; // Optional speech-to-text transcript
  final String? title; // Optional title for the clip
  final double? waveformData; // Cached waveform visualization data

  const AudioClipModel({
    required this.id,
    required this.pageId,
    required this.filePath,
    required this.startTimeMs,
    required this.durationSeconds,
    this.linkedStrokeIds = const [],
    required this.createdAt,
    this.isSynced = false,
    this.transcript,
    this.title,
    this.waveformData,
  });

  AudioClipModel copyWith({
    String? id,
    String? pageId,
    String? filePath,
    int? startTimeMs,
    int? durationSeconds,
    List<String>? linkedStrokeIds,
    DateTime? createdAt,
    bool? isSynced,
    String? transcript,
    String? title,
    double? waveformData,
  }) {
    return AudioClipModel(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      filePath: filePath ?? this.filePath,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      linkedStrokeIds: linkedStrokeIds ?? this.linkedStrokeIds,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      transcript: transcript ?? this.transcript,
      title: title ?? this.title,
      waveformData: waveformData ?? this.waveformData,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pageId': pageId,
    'filePath': filePath,
    'startTimeMs': startTimeMs,
    'durationSeconds': durationSeconds,
    'linkedStrokeIds': linkedStrokeIds,
    'createdAt': createdAt.toIso8601String(),
    'isSynced': isSynced,
    'transcript': transcript,
    'title': title,
    'waveformData': waveformData,
  };

  factory AudioClipModel.fromJson(Map<String, dynamic> json) => AudioClipModel(
    id: json['id'] ?? '',
    pageId: json['pageId'] ?? '',
    filePath: json['filePath'] ?? '',
    startTimeMs: json['startTimeMs'] ?? 0,
    durationSeconds: json['durationSeconds'] ?? 0,
    linkedStrokeIds: List<String>.from(json['linkedStrokeIds'] ?? []),
    createdAt: DateTime.parse(json['createdAt']),
    isSynced: json['isSynced'] ?? false,
    transcript: json['transcript'],
    title: json['title'],
    waveformData: json['waveformData']?.toDouble(),
  );

  /// Create a new audio clip
  factory AudioClipModel.create({
    required String id,
    required String pageId,
    required String filePath,
    required int startTimeMs,
    int durationSeconds = 0,
    String? title,
  }) {
    return AudioClipModel(
      id: id,
      pageId: pageId,
      filePath: filePath,
      startTimeMs: startTimeMs,
      durationSeconds: durationSeconds,
      createdAt: DateTime.now(),
      title: title,
    );
  }

  /// Get formatted duration string (MM:SS)
  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get short duration string
  String get shortDuration {
    if (durationSeconds < 60) {
      return '${durationSeconds}s';
    } else if (durationSeconds < 3600) {
      final minutes = durationSeconds ~/ 60;
      final seconds = durationSeconds % 60;
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    } else {
      final hours = durationSeconds ~/ 3600;
      final minutes = (durationSeconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    }
  }

  /// Check if clip has transcript
  bool get hasTranscript => transcript != null && transcript!.isNotEmpty;

  /// Check if clip has linked strokes
  bool get hasLinkedStrokes => linkedStrokeIds.isNotEmpty;

  /// Get end time in milliseconds
  int get endTimeMs => startTimeMs + (durationSeconds * 1000);

  /// Get display title
  String get displayTitle => title ?? 'Recording ${formattedDuration}';

  /// Check if a timestamp falls within this clip
  bool containsTimestamp(int timestampMs) {
    return timestampMs >= startTimeMs && timestampMs <= endTimeMs;
  }

  /// Get playback position (0.0 to 1.0) for a given timestamp
  double getPlaybackPosition(int timestampMs) {
    if (durationSeconds == 0) return 0.0;
    final elapsed = timestampMs - startTimeMs;
    return (elapsed / (durationSeconds * 1000)).clamp(0.0, 1.0);
  }

  /// Add a stroke ID to linked strokes
  AudioClipModel linkStroke(String strokeId) {
    if (linkedStrokeIds.contains(strokeId)) return this;
    return copyWith(linkedStrokeIds: [...linkedStrokeIds, strokeId]);
  }

  /// Remove a stroke ID from linked strokes
  AudioClipModel unlinkStroke(String strokeId) {
    return copyWith(
      linkedStrokeIds: linkedStrokeIds.where((id) => id != strokeId).toList(),
    );
  }
}

/// Represents a segment of audio playback with associated strokes
class AudioPlaybackSegment {
  final int startMs;
  final int endMs;
  final List<String> strokeIds;

  const AudioPlaybackSegment({
    required this.startMs,
    required this.endMs,
    required this.strokeIds,
  });

  int get durationMs => endMs - startMs;
}
