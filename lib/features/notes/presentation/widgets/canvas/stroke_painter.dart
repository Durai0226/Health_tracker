import 'package:flutter/material.dart';
import '../../../data/models/stroke_model.dart';

/// Custom painter for rendering strokes with smooth curves and pressure sensitivity
class StrokePainter extends CustomPainter {
  final List<StrokeModel> strokes;
  final StrokeModel? currentStroke;
  final double zoom;
  final Offset pan;

  StrokePainter({
    required this.strokes,
    this.currentStroke,
    this.zoom = 1.0,
    this.pan = Offset.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoom);

    // Draw all completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw current stroke being drawn
    if (currentStroke != null && currentStroke!.points.isNotEmpty) {
      _drawStroke(canvas, currentStroke!);
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, StrokeModel stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = stroke.colorValue.withOpacity(stroke.opacity)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = stroke.strokeCap
      ..strokeJoin = stroke.strokeJoin
      ..style = PaintingStyle.stroke
      ..blendMode = stroke.blendMode
      ..isAntiAlias = true;

    switch (stroke.tool) {
      case DrawingTool.pen:
        _drawSmoothStroke(canvas, stroke, paint);
        break;
      case DrawingTool.pencil:
        _drawPencilStroke(canvas, stroke, paint);
        break;
      case DrawingTool.highlighter:
        _drawHighlighterStroke(canvas, stroke, paint);
        break;
      case DrawingTool.marker:
        _drawMarkerStroke(canvas, stroke, paint);
        break;
      case DrawingTool.eraser:
        _drawEraserStroke(canvas, stroke, paint);
        break;
    }
  }

  /// Draw smooth stroke with bezier curves and pressure sensitivity
  void _drawSmoothStroke(Canvas canvas, StrokeModel stroke, Paint paint) {
    if (stroke.points.length < 2) return;

    final path = Path();
    final points = stroke.points;

    // Start the path
    path.moveTo(points[0].x, points[0].y);

    if (points.length == 2) {
      // Simple line for 2 points
      path.lineTo(points[1].x, points[1].y);
    } else {
      // Use quadratic bezier curves for smooth strokes
      for (int i = 1; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];

        // Calculate control point
        final midX = (p1.x + p2.x) / 2;
        final midY = (p1.y + p2.y) / 2;

        // Apply pressure variation
        final pressure = p1.pressure;
        paint.strokeWidth = stroke.strokeWidth * pressure;

        path.quadraticBezierTo(p1.x, p1.y, midX, midY);
      }

      // Draw to the last point
      final lastPoint = points.last;
      path.lineTo(lastPoint.x, lastPoint.y);
    }

    canvas.drawPath(path, paint);
  }

  /// Draw pencil-style stroke with slight texture
  void _drawPencilStroke(Canvas canvas, StrokeModel stroke, Paint paint) {
    if (stroke.points.length < 2) return;

    paint.strokeWidth = stroke.strokeWidth * 0.8;
    paint.color = paint.color.withOpacity(0.85);

    final path = Path();
    final points = stroke.points;

    path.moveTo(points[0].x, points[0].y);

    for (int i = 1; i < points.length; i++) {
      final p1 = points[i];
      
      // Add slight jitter for pencil texture
      path.lineTo(
        p1.x + (i % 2 == 0 ? 0.2 : -0.2),
        p1.y + (i % 2 == 0 ? -0.2 : 0.2),
      );
    }

    canvas.drawPath(path, paint);
  }

  /// Draw highlighter-style stroke with flat brush effect
  void _drawHighlighterStroke(Canvas canvas, StrokeModel stroke, Paint paint) {
    if (stroke.points.length < 2) return;

    paint.strokeWidth = stroke.strokeWidth * 2;
    paint.strokeCap = StrokeCap.square;
    paint.color = paint.color.withOpacity(0.4);

    final path = Path();
    final points = stroke.points;

    path.moveTo(points[0].x, points[0].y);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].x, points[i].y);
    }

    canvas.drawPath(path, paint);
  }

  /// Draw marker-style stroke with solid fill
  void _drawMarkerStroke(Canvas canvas, StrokeModel stroke, Paint paint) {
    if (stroke.points.length < 2) return;

    paint.strokeWidth = stroke.strokeWidth * 1.5;
    paint.strokeCap = StrokeCap.round;

    final path = Path();
    final points = stroke.points;

    path.moveTo(points[0].x, points[0].y);

    for (int i = 1; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final midX = (p1.x + p2.x) / 2;
      final midY = (p1.y + p2.y) / 2;
      path.quadraticBezierTo(p1.x, p1.y, midX, midY);
    }

    if (points.length > 1) {
      path.lineTo(points.last.x, points.last.y);
    }

    canvas.drawPath(path, paint);
  }

  /// Draw eraser stroke (white overlay)
  void _drawEraserStroke(Canvas canvas, StrokeModel stroke, Paint paint) {
    if (stroke.points.length < 2) return;

    paint.color = Colors.white;
    paint.blendMode = BlendMode.srcOver;
    paint.strokeWidth = stroke.strokeWidth;
    paint.strokeCap = StrokeCap.round;

    final path = Path();
    final points = stroke.points;

    path.moveTo(points[0].x, points[0].y);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].x, points[i].y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan;
  }
}

/// Painter for rendering a single stroke preview (for thumbnails)
class StrokePreviewPainter extends CustomPainter {
  final List<StrokeModel> strokes;
  final Size originalSize;

  StrokePreviewPainter({
    required this.strokes,
    required this.originalSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;

    // Calculate scale to fit preview
    final scaleX = size.width / originalSize.width;
    final scaleY = size.height / originalSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    canvas.save();
    canvas.scale(scale);

    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;

      final paint = Paint()
        ..color = stroke.colorValue
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final path = Path();
      path.moveTo(stroke.points[0].x, stroke.points[0].y);

      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].x, stroke.points[i].y);
      }

      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StrokePreviewPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
