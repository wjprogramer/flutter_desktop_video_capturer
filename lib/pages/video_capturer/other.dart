import 'dart:math' as math;

import 'package:flutter/material.dart';

class RectOnVideoPainter extends CustomPainter {
  final Rect? rectVideoPx;
  final Rect Function(Rect) toScreen;

  RectOnVideoPainter({required this.rectVideoPx, required this.toScreen});

  @override
  void paint(Canvas canvas, Size size) {
    if (rectVideoPx == null) return;
    final r = toScreen(_normalize(rectVideoPx!)); // 先正規化，確保 left<right, top<bottom

    final fill = Paint()
      ..color = Colors.red.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(r, fill);
    canvas.drawRect(r, stroke);
  }

  Rect _normalize(Rect r) {
    final left = math.min(r.left, r.right);
    final right = math.max(r.left, r.right);
    final top = math.min(r.top, r.bottom);
    final bottom = math.max(r.top, r.bottom);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldRepaint(covariant RectOnVideoPainter oldDelegate) {
    return oldDelegate.rectVideoPx != rectVideoPx;
  }
}

class RectPainter extends CustomPainter {
  final Offset? start;
  final Offset? end;
  final Rect? selectedRect;

  RectPainter(this.start, this.end, this.selectedRect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final border = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (start != null && end != null) {
      final rect = Rect.fromPoints(start!, end!);
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, border);
    }

    if (selectedRect != null) {
      canvas.drawRect(selectedRect!, border);
    }
  }

  @override
  bool shouldRepaint(covariant RectPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end || oldDelegate.selectedRect != selectedRect;
  }
}
