import 'package:flutter/material.dart';
import '../theme/nunito_theme.dart';
import '../models/medicine_enums.dart';

/// Visual representation of a pill/medication with customizable shape and color
class NunitoPillVisual extends StatelessWidget {
  final MedicineColor? color;
  final MedicineShape? shape;
  final double size;
  final bool showShadow;
  final String? imprint;

  const NunitoPillVisual({
    super.key,
    this.color,
    this.shape,
    this.size = 60,
    this.showShadow = true,
    this.imprint,
  });

  Color get _pillColor {
    if (color == null) return NunitoTheme.pillColors[0];
    final index = color!.index;
    if (index >= 0 && index < NunitoTheme.pillColors.length) {
      return NunitoTheme.pillColors[index];
    }
    return NunitoTheme.pillColors[0];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: _pillColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        painter: _PillPainter(
          color: _pillColor,
          shape: shape ?? MedicineShape.round,
          imprint: imprint,
        ),
        size: Size(size, size),
      ),
    );
  }
}

class _PillPainter extends CustomPainter {
  final Color color;
  final MedicineShape shape;
  final String? imprint;

  _PillPainter({
    required this.color,
    required this.shape,
    this.imprint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    final minDim = size.width < size.height ? size.width : size.height;

    switch (shape) {
      case MedicineShape.round:
        _drawRoundPill(canvas, center, minDim, paint, highlightPaint, outlinePaint);
        break;
      case MedicineShape.oval:
        _drawOvalPill(canvas, size, paint, highlightPaint, outlinePaint);
        break;
      case MedicineShape.capsule:
        _drawCapsule(canvas, size, paint, highlightPaint, outlinePaint);
        break;
      case MedicineShape.rectangle:
        _drawRectanglePill(canvas, size, paint, highlightPaint, outlinePaint);
        break;
      case MedicineShape.square:
        _drawSquarePill(canvas, size, paint, highlightPaint, outlinePaint);
        break;
      case MedicineShape.diamond:
        _drawDiamondPill(canvas, size, paint, highlightPaint, outlinePaint);
        break;
      case MedicineShape.triangle:
        _drawTrianglePill(canvas, size, paint, highlightPaint, outlinePaint);
        break;
      case MedicineShape.heart:
        _drawHeartPill(canvas, size, paint, highlightPaint, outlinePaint);
        break;
      case MedicineShape.other:
        _drawRoundPill(canvas, center, minDim, paint, highlightPaint, outlinePaint);
        break;
    }

    // Draw imprint text if provided
    if (imprint != null && imprint!.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: imprint!.length > 4 ? imprint!.substring(0, 4) : imprint,
          style: TextStyle(
            color: _getContrastColor(color),
            fontSize: minDim * 0.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawRoundPill(Canvas canvas, Offset center, double size, 
      Paint paint, Paint highlightPaint, Paint outlinePaint) {
    final radius = size * 0.4;
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius, outlinePaint);
    
    // Highlight
    final highlightPath = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius * 0.85),
        -2.5,
        1.5,
      );
    canvas.drawPath(highlightPath, highlightPaint);
  }

  void _drawOvalPill(Canvas canvas, Size size, 
      Paint paint, Paint highlightPaint, Paint outlinePaint) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.8,
      height: size.height * 0.5,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.height * 0.25));
    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, outlinePaint);
  }

  void _drawCapsule(Canvas canvas, Size size, 
      Paint paint, Paint highlightPaint, Paint outlinePaint) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.85,
      height: size.height * 0.4,
    );
    final radius = rect.height / 2;
    
    // Left half
    final leftPaint = Paint()..color = color;
    final leftRect = Rect.fromLTWH(rect.left, rect.top, rect.width / 2, rect.height);
    canvas.drawRRect(
      RRect.fromRectAndCorners(leftRect, 
        topLeft: Radius.circular(radius),
        bottomLeft: Radius.circular(radius),
      ),
      leftPaint,
    );
    
    // Right half (slightly different shade)
    final rightPaint = Paint()..color = _adjustBrightness(color, 0.9);
    final rightRect = Rect.fromLTWH(rect.left + rect.width / 2, rect.top, rect.width / 2, rect.height);
    canvas.drawRRect(
      RRect.fromRectAndCorners(rightRect,
        topRight: Radius.circular(radius),
        bottomRight: Radius.circular(radius),
      ),
      rightPaint,
    );
    
    // Divider line
    canvas.drawLine(
      Offset(size.width / 2, rect.top),
      Offset(size.width / 2, rect.bottom),
      Paint()..color = Colors.black.withOpacity(0.1)..strokeWidth = 1,
    );
    
    // Outline
    final fullRRect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(fullRRect, outlinePaint);
  }

  void _drawRectanglePill(Canvas canvas, Size size, 
      Paint paint, Paint highlightPaint, Paint outlinePaint) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.height * 0.45,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, outlinePaint);
  }

  void _drawSquarePill(Canvas canvas, Size size, 
      Paint paint, Paint highlightPaint, Paint outlinePaint) {
    final dim = size.width < size.height ? size.width : size.height;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: dim * 0.6,
      height: dim * 0.6,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, outlinePaint);
  }

  void _drawDiamondPill(Canvas canvas, Size size, 
      Paint paint, Paint highlightPaint, Paint outlinePaint) {
    final center = Offset(size.width / 2, size.height / 2);
    final dim = (size.width < size.height ? size.width : size.height) * 0.4;
    
    final path = Path()
      ..moveTo(center.dx, center.dy - dim)
      ..lineTo(center.dx + dim, center.dy)
      ..lineTo(center.dx, center.dy + dim)
      ..lineTo(center.dx - dim, center.dy)
      ..close();
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, outlinePaint);
  }

  void _drawTrianglePill(Canvas canvas, Size size, 
      Paint paint, Paint highlightPaint, Paint outlinePaint) {
    final center = Offset(size.width / 2, size.height / 2);
    final dim = (size.width < size.height ? size.width : size.height) * 0.4;
    
    final path = Path()
      ..moveTo(center.dx, center.dy - dim)
      ..lineTo(center.dx + dim, center.dy + dim * 0.7)
      ..lineTo(center.dx - dim, center.dy + dim * 0.7)
      ..close();
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, outlinePaint);
  }

  void _drawHeartPill(Canvas canvas, Size size, 
      Paint paint, Paint highlightPaint, Paint outlinePaint) {
    final center = Offset(size.width / 2, size.height / 2);
    final dim = (size.width < size.height ? size.width : size.height) * 0.35;
    
    final path = Path();
    path.moveTo(center.dx, center.dy + dim);
    path.cubicTo(
      center.dx - dim * 2, center.dy,
      center.dx - dim, center.dy - dim * 1.2,
      center.dx, center.dy - dim * 0.4,
    );
    path.cubicTo(
      center.dx + dim, center.dy - dim * 1.2,
      center.dx + dim * 2, center.dy,
      center.dx, center.dy + dim,
    );
    path.close();
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, outlinePaint);
  }

  Color _adjustBrightness(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red * factor).round().clamp(0, 255),
      (color.green * factor).round().clamp(0, 255),
      (color.blue * factor).round().clamp(0, 255),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  @override
  bool shouldRepaint(covariant _PillPainter oldDelegate) {
    return oldDelegate.color != color || 
           oldDelegate.shape != shape || 
           oldDelegate.imprint != imprint;
  }
}

/// Small pill indicator for lists
class NunitoPillIndicator extends StatelessWidget {
  final MedicineColor? color;
  final MedicineShape? shape;
  final double size;

  const NunitoPillIndicator({
    super.key,
    this.color,
    this.shape,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return NunitoPillVisual(
      color: color,
      shape: shape,
      size: size,
      showShadow: false,
    );
  }
}

/// Dosage form icon widget
class NunitoDosageIcon extends StatelessWidget {
  final DosageForm dosageForm;
  final double size;
  final Color? color;

  const NunitoDosageIcon({
    super.key,
    required this.dosageForm,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      _getIcon(),
      size: size,
      color: color ?? NunitoTheme.primary,
    );
  }

  IconData _getIcon() {
    switch (dosageForm) {
      case DosageForm.tablet:
        return Icons.medication_rounded;
      case DosageForm.capsule:
        return Icons.medication_liquid_rounded;
      case DosageForm.syrup:
        return Icons.local_drink_rounded;
      case DosageForm.injection:
        return Icons.vaccines_rounded;
      case DosageForm.drops:
        return Icons.water_drop_rounded;
      case DosageForm.cream:
        return Icons.sanitizer_rounded;
      case DosageForm.inhaler:
        return Icons.air_rounded;
      case DosageForm.patch:
        return Icons.healing_rounded;
      case DosageForm.suppository:
        return Icons.medication_rounded;
      case DosageForm.powder:
        return Icons.grain_rounded;
      case DosageForm.spray:
        return Icons.wb_cloudy_rounded;
      case DosageForm.gel:
        return Icons.opacity_rounded;
      case DosageForm.ointment:
        return Icons.healing_rounded;
      case DosageForm.lozenge:
        return Icons.circle_rounded;
      case DosageForm.solution:
        return Icons.science_rounded;
      case DosageForm.suspension:
        return Icons.science_rounded;
      case DosageForm.other:
        return Icons.medical_services_rounded;
    }
  }
}
