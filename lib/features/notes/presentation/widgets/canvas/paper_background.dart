import 'package:flutter/material.dart';
import '../../../data/models/page_model.dart';
import '../../../theme/livescribe_theme.dart';

/// Custom painter for rendering paper background templates
class PaperBackgroundPainter extends CustomPainter {
  final NotebookTemplate template;
  final Color? backgroundColor;
  final bool isDark;
  final double zoom;
  final Offset pan;

  PaperBackgroundPainter({
    required this.template,
    this.backgroundColor,
    this.isDark = false,
    this.zoom = 1.0,
    this.pan = Offset.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    final bgColor = backgroundColor ?? _getDefaultBackgroundColor();
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    canvas.save();
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoom);

    final scaledSize = Size(size.width / zoom, size.height / zoom);

    switch (template) {
      case NotebookTemplate.blank:
        // No lines, just background
        break;
      case NotebookTemplate.lined:
        _drawLinedPaper(canvas, scaledSize);
        break;
      case NotebookTemplate.grid:
        _drawGridPaper(canvas, scaledSize);
        break;
      case NotebookTemplate.dotted:
        _drawDottedPaper(canvas, scaledSize);
        break;
      case NotebookTemplate.cornell:
        _drawCornellPaper(canvas, scaledSize);
        break;
      case NotebookTemplate.music:
        _drawMusicPaper(canvas, scaledSize);
        break;
    }

    canvas.restore();
  }

  Color _getDefaultBackgroundColor() {
    switch (template) {
      case NotebookTemplate.blank:
        return isDark ? LivescribeTheme.darkSurface : LivescribeTheme.canvasWhite;
      case NotebookTemplate.lined:
        return isDark ? LivescribeTheme.darkSurface : LivescribeTheme.canvasBeige;
      case NotebookTemplate.grid:
        return isDark ? LivescribeTheme.darkSurface : LivescribeTheme.canvasGrid;
      case NotebookTemplate.dotted:
        return isDark ? LivescribeTheme.darkSurface : LivescribeTheme.canvasWhite;
      case NotebookTemplate.cornell:
        return isDark ? LivescribeTheme.darkSurface : LivescribeTheme.canvasWhite;
      case NotebookTemplate.music:
        return isDark ? LivescribeTheme.darkSurface : LivescribeTheme.canvasBeige;
    }
  }

  void _drawLinedPaper(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isDark 
          ? Colors.white.withOpacity(0.1) 
          : LivescribeTheme.linedPaperLine
      ..strokeWidth = 1.0;

    final marginPaint = Paint()
      ..color = isDark 
          ? Colors.red.withOpacity(0.2) 
          : LivescribeTheme.marginLine
      ..strokeWidth = 1.5;

    const lineSpacing = LivescribeTheme.lineSpacing;
    const marginLeft = LivescribeTheme.marginLeft;

    // Draw margin line
    canvas.drawLine(
      Offset(marginLeft, 0),
      Offset(marginLeft, size.height),
      marginPaint,
    );

    // Draw horizontal lines
    double y = lineSpacing;
    while (y < size.height) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        linePaint,
      );
      y += lineSpacing;
    }
  }

  void _drawGridPaper(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = isDark 
          ? Colors.white.withOpacity(0.08) 
          : LivescribeTheme.gridPaperLine
      ..strokeWidth = 0.5;

    const gridSize = LivescribeTheme.gridSize;

    // Draw vertical lines
    double x = 0;
    while (x <= size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
      x += gridSize;
    }

    // Draw horizontal lines
    double y = 0;
    while (y <= size.height) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
      y += gridSize;
    }
  }

  void _drawDottedPaper(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = isDark 
          ? Colors.white.withOpacity(0.15) 
          : LivescribeTheme.textTertiary.withOpacity(0.3);

    const spacing = 20.0;
    const dotRadius = 1.0;

    double x = spacing;
    while (x < size.width) {
      double y = spacing;
      while (y < size.height) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
        y += spacing;
      }
      x += spacing;
    }
  }

  void _drawCornellPaper(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isDark 
          ? Colors.white.withOpacity(0.1) 
          : LivescribeTheme.linedPaperLine
      ..strokeWidth = 1.0;

    final dividerPaint = Paint()
      ..color = isDark 
          ? Colors.white.withOpacity(0.2) 
          : LivescribeTheme.border
      ..strokeWidth = 2.0;

    const lineSpacing = LivescribeTheme.lineSpacing;
    const cueColumnWidth = 70.0;
    const summaryHeight = 80.0;

    // Draw cue column divider
    canvas.drawLine(
      Offset(cueColumnWidth, 0),
      Offset(cueColumnWidth, size.height - summaryHeight),
      dividerPaint,
    );

    // Draw summary area divider
    canvas.drawLine(
      Offset(0, size.height - summaryHeight),
      Offset(size.width, size.height - summaryHeight),
      dividerPaint,
    );

    // Draw horizontal lines in main area
    double y = lineSpacing;
    while (y < size.height - summaryHeight) {
      canvas.drawLine(
        Offset(cueColumnWidth + 10, y),
        Offset(size.width, y),
        linePaint,
      );
      y += lineSpacing;
    }

    // Draw lines in summary area
    y = size.height - summaryHeight + lineSpacing;
    while (y < size.height) {
      canvas.drawLine(
        Offset(10, y),
        Offset(size.width - 10, y),
        linePaint,
      );
      y += lineSpacing;
    }

    // Draw labels
    final labelPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Cue label
    labelPainter.text = TextSpan(
      text: 'CUES',
      style: TextStyle(
        color: isDark ? Colors.white38 : LivescribeTheme.textTertiary,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
    labelPainter.layout();
    labelPainter.paint(canvas, const Offset(15, 10));

    // Notes label
    labelPainter.text = TextSpan(
      text: 'NOTES',
      style: TextStyle(
        color: isDark ? Colors.white38 : LivescribeTheme.textTertiary,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
    labelPainter.layout();
    labelPainter.paint(canvas, Offset(cueColumnWidth + 15, 10));

    // Summary label
    labelPainter.text = TextSpan(
      text: 'SUMMARY',
      style: TextStyle(
        color: isDark ? Colors.white38 : LivescribeTheme.textTertiary,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
    labelPainter.layout();
    labelPainter.paint(canvas, Offset(15, size.height - summaryHeight + 10));
  }

  void _drawMusicPaper(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isDark 
          ? Colors.white.withOpacity(0.12) 
          : LivescribeTheme.textTertiary.withOpacity(0.4)
      ..strokeWidth = 0.8;

    const staffSpacing = 8.0; // Space between staff lines
    const staffGroupSpacing = 60.0; // Space between staff groups
    const linesPerStaff = 5;

    double y = 40.0;
    while (y < size.height - 40) {
      // Draw one staff (5 lines)
      for (int i = 0; i < linesPerStaff; i++) {
        canvas.drawLine(
          Offset(30, y + i * staffSpacing),
          Offset(size.width - 30, y + i * staffSpacing),
          linePaint,
        );
      }
      y += linesPerStaff * staffSpacing + staffGroupSpacing;
    }
  }

  @override
  bool shouldRepaint(covariant PaperBackgroundPainter oldDelegate) {
    return oldDelegate.template != template ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pan != pan;
  }
}

/// Widget that displays paper background with template
class PaperBackground extends StatelessWidget {
  final NotebookTemplate template;
  final Color? backgroundColor;
  final Widget? child;

  const PaperBackground({
    super.key,
    this.template = NotebookTemplate.blank,
    this.backgroundColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return CustomPaint(
      painter: PaperBackgroundPainter(
        template: template,
        backgroundColor: backgroundColor,
        isDark: isDark,
      ),
      child: child,
    );
  }
}
