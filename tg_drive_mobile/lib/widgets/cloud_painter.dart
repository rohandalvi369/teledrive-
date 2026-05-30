import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2 + 4;
    final r = size.width * 0.25;

    path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    path.addOval(Rect.fromCircle(center: Offset(cx - r * 0.7, cy + r * 0.1), radius: r * 0.75));
    path.addOval(Rect.fromCircle(center: Offset(cx + r * 0.7, cy + r * 0.1), radius: r * 0.65));
    path.addOval(Rect.fromCircle(center: Offset(cx - r * 0.35, cy - r * 0.4), radius: r * 0.55));
    path.addOval(Rect.fromCircle(center: Offset(cx + r * 0.35, cy - r * 0.35), radius: r * 0.5));

    canvas.drawPath(Path.combine(PathOperation.union, path, Path()), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
