import 'dart:ui';

/// Tool types for drawing
enum DrawingTool {
  pen,
  pencil,
  highlighter,
  marker,
  eraser,
}

/// Represents a point in a stroke with pressure data
class StrokePoint {
  final double x;
  final double y;
  final double pressure;
  final int timestamp; // milliseconds since epoch

  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
    required this.timestamp,
  });

  Offset get offset => Offset(x, y);

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'p': pressure,
    't': timestamp,
  };

  factory StrokePoint.fromJson(Map<String, dynamic> json) => StrokePoint(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    pressure: (json['p'] as num?)?.toDouble() ?? 1.0,
    timestamp: json['t'] as int,
  );

  /// Create from offset with default pressure
  factory StrokePoint.fromOffset(Offset offset, {double pressure = 1.0}) {
    return StrokePoint(
      x: offset.dx,
      y: offset.dy,
      pressure: pressure,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Represents a single stroke (continuous line) drawn on canvas
class StrokeModel {
  final String id;
  final List<StrokePoint> points;
  final String color; // Hex color string
  final double strokeWidth;
  final DrawingTool tool;
  final DateTime createdAt;
  final String? linkedAudioClipId; // For audio-synced playback

  const StrokeModel({
    required this.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.tool = DrawingTool.pen,
    required this.createdAt,
    this.linkedAudioClipId,
  });

  StrokeModel copyWith({
    String? id,
    List<StrokePoint>? points,
    String? color,
    double? strokeWidth,
    DrawingTool? tool,
    DateTime? createdAt,
    String? linkedAudioClipId,
  }) {
    return StrokeModel(
      id: id ?? this.id,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      tool: tool ?? this.tool,
      createdAt: createdAt ?? this.createdAt,
      linkedAudioClipId: linkedAudioClipId ?? this.linkedAudioClipId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'points': points.map((p) => p.toJson()).toList(),
    'color': color,
    'strokeWidth': strokeWidth,
    'tool': tool.index,
    'createdAt': createdAt.toIso8601String(),
    'linkedAudioClipId': linkedAudioClipId,
  };

  factory StrokeModel.fromJson(Map<String, dynamic> json) => StrokeModel(
    id: json['id'] ?? '',
    points: (json['points'] as List<dynamic>)
        .map((p) => StrokePoint.fromJson(p))
        .toList(),
    color: json['color'] ?? '#1A1D26',
    strokeWidth: (json['strokeWidth'] as num).toDouble(),
    tool: DrawingTool.values[json['tool'] ?? 0],
    createdAt: DateTime.parse(json['createdAt']),
    linkedAudioClipId: json['linkedAudioClipId'],
  );

  /// Create a new stroke
  factory StrokeModel.create({
    required String id,
    required String color,
    required double strokeWidth,
    DrawingTool tool = DrawingTool.pen,
    String? linkedAudioClipId,
  }) {
    return StrokeModel(
      id: id,
      points: [],
      color: color,
      strokeWidth: strokeWidth,
      tool: tool,
      createdAt: DateTime.now(),
      linkedAudioClipId: linkedAudioClipId,
    );
  }

  /// Add a point to the stroke
  StrokeModel addPoint(StrokePoint point) {
    return copyWith(points: [...points, point]);
  }

  /// Add multiple points
  StrokeModel addPoints(List<StrokePoint> newPoints) {
    return copyWith(points: [...points, ...newPoints]);
  }

  /// Get bounding box of stroke
  Rect get boundingBox {
    if (points.isEmpty) return Rect.zero;
    
    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;
    
    for (final point in points) {
      if (point.x < minX) minX = point.x;
      if (point.x > maxX) maxX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }
    
    final padding = strokeWidth / 2;
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  /// Get start timestamp
  int? get startTimestamp => points.isNotEmpty ? points.first.timestamp : null;

  /// Get end timestamp  
  int? get endTimestamp => points.isNotEmpty ? points.last.timestamp : null;

  /// Get duration in milliseconds
  int get durationMs {
    if (points.length < 2) return 0;
    return points.last.timestamp - points.first.timestamp;
  }

  /// Check if stroke is empty
  bool get isEmpty => points.isEmpty;

  /// Check if stroke has enough points to render
  bool get isValid => points.length >= 2;

  /// Get opacity based on tool
  double get opacity {
    switch (tool) {
      case DrawingTool.highlighter:
        return 0.4;
      case DrawingTool.pencil:
        return 0.8;
      default:
        return 1.0;
    }
  }

  /// Get blend mode based on tool
  BlendMode get blendMode {
    switch (tool) {
      case DrawingTool.highlighter:
        return BlendMode.multiply;
      case DrawingTool.eraser:
        return BlendMode.clear;
      default:
        return BlendMode.srcOver;
    }
  }

  /// Get stroke cap style
  StrokeCap get strokeCap {
    switch (tool) {
      case DrawingTool.marker:
        return StrokeCap.square;
      default:
        return StrokeCap.round;
    }
  }

  /// Get stroke join style
  StrokeJoin get strokeJoin {
    switch (tool) {
      case DrawingTool.marker:
        return StrokeJoin.bevel;
      default:
        return StrokeJoin.round;
    }
  }

  /// Parse color string to Color
  Color get colorValue {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1A1D26);
    }
  }
}
