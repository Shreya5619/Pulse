import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/lifecanvas_service.dart';

// ─── Gantt screen-time strip (mirrors the web prototype's canvas Gantt) ────────
class LifeCanvasGantt extends StatelessWidget {
  final List<AppUsageStat> stats;
  final List<PredictedEvent> predictions;
  final double viewOffsetHours; // pan offset from the canvas
  final double zoomScale;       // zoom level from the canvas

  static const double _rowH = 13.0;
  static const double _labelW = 52.0;

  const LifeCanvasGantt({
    super.key,
    required this.stats,
    required this.predictions,
    required this.viewOffsetHours,
    required this.zoomScale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: const Color(0xFF020412),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: CustomPaint(
        painter: _GanttPainter(
          stats: stats,
          predictions: predictions,
          viewOffsetHours: viewOffsetHours,
          zoomScale: zoomScale,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GanttPainter extends CustomPainter {
  final List<AppUsageStat> stats;
  final List<PredictedEvent> predictions;
  final double viewOffsetHours;
  final double zoomScale;

  _GanttPainter({
    required this.stats,
    required this.predictions,
    required this.viewOffsetHours,
    required this.zoomScale,
  });

  static const _labelW = 52.0;
  static const _rowH = 12.0;
  static const _rowGap = 2.0;

  // Maps hour-of-day to screen X
  double _hToX(double h, double width) {
    const pxPerHour = 200.0;
    final graphX = 100.0 + h * pxPerHour;
    return (graphX - viewOffsetHours * pxPerHour) * zoomScale + _labelW;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rows = stats.take(5).toList();
    final labelPaint = TextPainter(textDirection: TextDirection.ltr);
    final barPaint = Paint()..style = PaintingStyle.fill;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, _labelW, size.height),
        Paint()..color = const Color(0xFF02040E));

    // Alternating row backgrounds + labels
    const colors = [
      Color(0xFF00E5FF), Color(0xFF4EE2C9), Color(0xFFBF5AF2),
      Color(0xFFFFB300), Color(0xFFFF5252),
    ];

    for (int i = 0; i < rows.length; i++) {
      final y = i * (_rowH + _rowGap) + 6.0;
      final c = colors[i % colors.length];

      // Alternate row tint
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(_labelW, y, size.width - _labelW, _rowH),
          Paint()..color = Colors.white.withValues(alpha: 0.015),
        );
      }

      // Label
      labelPaint
        ..text = TextSpan(
          text: rows[i].appName.length > 6 ? rows[i].appName.substring(0, 6) : rows[i].appName,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 7),
        )
        ..layout(maxWidth: _labelW - 4);
      labelPaint.paint(canvas, Offset(4, y + 2));

      // Bar width proportional to usage minutes (capped at 12h)
      final mins = math.min(rows[i].totalMinutes, 720);
      final durationH = mins / 60.0;
      final startH = 8.0 + i * 0.5; // staggered start times
      final x1 = math.max(_hToX(startH, size.width), _labelW);
      final x2 = _hToX(startH + durationH, size.width);
      final w = x2 - x1;

      if (w > 2) {
        barPaint.color = c.withValues(alpha: 0.65);
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x1, y + 1, math.max(w, 2), _rowH - 2),
          const Radius.circular(3),
        );
        canvas.drawRRect(rrect, barPaint);
      }
    }

    // Phantom (predicted) bars — dashed outline
    for (final pred in predictions) {
      final rowIdx = math.min(pred.name.hashCode % rows.length, rows.length - 1).abs();
      final y = rowIdx * (_rowH + _rowGap) + 6.0;
      final x1 = math.max(_hToX(pred.futureHour, size.width), _labelW);
      final x2 = _hToX(pred.futureHour + pred.durationHours, size.width);
      final w = x2 - x1;
      if (w < 2) continue;

      final dashPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFFBF5AF2).withValues(alpha: 0.7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x1, y + 1, math.max(w, 2), _rowH - 2),
          const Radius.circular(3),
        ),
        dashPaint,
      );
    }

    // NOW line
    final now = DateTime.now();
    final nowH = now.hour + now.minute / 60.0;
    final nowX = _hToX(nowH, size.width);
    if (nowX > _labelW && nowX < size.width) {
      canvas.drawLine(
        Offset(nowX, 0),
        Offset(nowX, size.height),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(_GanttPainter o) =>
      o.viewOffsetHours != viewOffsetHours ||
      o.zoomScale != zoomScale ||
      o.predictions.length != predictions.length;
}
