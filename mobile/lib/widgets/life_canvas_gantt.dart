import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/lifecanvas_service.dart';
import '../services/life_canvas_timeline_math.dart';

/// Gantt overlay synced to Life Tree X scale (lifecanvas/app.js ganttCanvas).
class LifeCanvasGantt extends StatelessWidget {
  final List<AppUsageStat> stats;
  final List<PredictedEvent> predictions;
  final Matrix4 transform;
  final DateTime baseDate;

  static const double stripHeight = 130.0;

  const LifeCanvasGantt({
    super.key,
    required this.stats,
    required this.predictions,
    required this.transform,
    required this.baseDate,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: stripHeight,
      width: double.infinity,
      child: CustomPaint(
        painter: _GanttPainter(
          stats: stats,
          predictions: predictions,
          transform: transform,
          baseDate: baseDate,
        ),
      ),
    );
  }
}

class _GanttPainter extends CustomPainter {
  final List<AppUsageStat> stats;
  final List<PredictedEvent> predictions;
  final Matrix4 transform;
  final DateTime baseDate;

  _GanttPainter({
    required this.stats,
    required this.predictions,
    required this.transform,
    required this.baseDate,
  });

  static const _labelW = 56.0;
  static const _rowH = 14.0;
  static const _rowGap = 2.0;

  static const _ganttApps = [
    'Screen',
    'Messages',
    'Chrome',
    'Instagram',
    'YouTube',
    'WhatsApp',
    'Spotify',
  ];

  static const _appColors = {
    'Screen': Color(0xFF64FFDA),
    'Messages': Color(0xFF4ADE80),
    'Chrome': Color(0xFF60A5FA),
    'Instagram': Color(0xFFA78BFA),
    'YouTube': Color(0xFFE57373),
    'WhatsApp': Color(0xFF64B5F6),
    'Spotify': Color(0xFF81C784),
  };

  double _hourToScreenX(double h, double width) {
    final x = LifeCanvasTimelineMath.screenXFromHour(h, transform);
    return x.clamp(_labelW, width);
  }

  int _rowForApp(String name) {
    for (var i = 0; i < _ganttApps.length; i++) {
      if (_ganttApps[i].toLowerCase() == name.toLowerCase()) return i;
    }
    return name.hashCode.abs() % _ganttApps.length;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final isToday = LifeCanvasTimelineMath.isViewingToday(baseDate);
    final nowH = LifeCanvasTimelineMath.nowHourOnDate(baseDate);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, _labelW, size.height),
      Paint()..color = const Color(0xFF02040E).withValues(alpha: 0.9),
    );

    final labelPaint = TextPainter(textDirection: TextDirection.ltr);
    final barPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < _ganttApps.length; i++) {
      final y = i * (_rowH + _rowGap) + 6.0;
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(_labelW, y, size.width - _labelW, _rowH),
          Paint()..color = Colors.white.withValues(alpha: 0.015),
        );
      }
      labelPaint
        ..text = TextSpan(
          text: _ganttApps[i],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.28),
            fontSize: 7,
          ),
        )
        ..layout(maxWidth: _labelW - 4);
      labelPaint.paint(canvas, Offset(4, y + 2));
    }

    final rows = stats.take(8).toList();
    for (final stat in rows) {
      final rowIdx = _rowForApp(stat.appName);
      final y = rowIdx * (_rowH + _rowGap) + 6.0;
      final c = _appColors[_ganttApps[rowIdx]] ?? const Color(0xFF00E5FF);

      if (stat.hourlySegments.isNotEmpty) {
        for (final seg in stat.hourlySegments) {
          final startH = seg.hour.toDouble();
          if (isToday && startH >= nowH) continue;
          var endH = startH + seg.minutes / 60.0;
          if (isToday) endH = math.min(endH, nowH);
          if (endH <= startH) continue;
          final x1 = math.max(_hourToScreenX(startH, size.width), _labelW);
          final x2 = _hourToScreenX(endH, size.width);
          final w = x2 - x1;
          if (w < 1.5) continue;
          barPaint.color = c.withValues(alpha: stat.appName == 'Screen' ? 0.35 : 0.7);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x1, y + 1, math.max(w, 2), _rowH - 2),
              const Radius.circular(3),
            ),
            barPaint,
          );
        }
      } else if (isToday) {
        final durationH = math.min(stat.totalMinutes / 60.0, nowH);
        if (durationH > 0.05) {
          final startH = math.max(0.0, nowH - durationH);
          final x1 = math.max(_hourToScreenX(startH, size.width), _labelW);
          final x2 = _hourToScreenX(nowH, size.width);
          final w = x2 - x1;
          if (w > 1.5) {
            barPaint.color = c.withValues(alpha: 0.55);
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x1, y + 1, math.max(w, 2), _rowH - 2),
                const Radius.circular(3),
              ),
              barPaint,
            );
          }
        }
      }
    }

    for (final pred in predictions) {
      if (isToday && pred.futureHour <= nowH) continue;
      final app = pred.appName ?? '';
      final rowIdx = app.isNotEmpty ? _rowForApp(app) : (pred.name.hashCode.abs() % 7);
      final y = rowIdx * (_rowH + _rowGap) + 6.0;
      final endH = pred.futureHour + pred.durationHours;
      final x1 = math.max(_hourToScreenX(pred.futureHour, size.width), _labelW);
      final x2 = _hourToScreenX(endH, size.width);
      final w = x2 - x1;
      if (w < 2) continue;

      Color pc;
      try {
        pc = Color(int.parse(pred.color.replaceFirst('#', '0xFF')));
      } catch (_) {
        pc = const Color(0xFFBF5AF2);
      }
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = pc.withValues(alpha: 0.7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x1, y + 1, math.max(w, 2), _rowH - 2),
          const Radius.circular(3),
        ),
        dash,
      );
    }

    if (isToday) {
      final nowX = _hourToScreenX(nowH, size.width);
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
  }

  @override
  bool shouldRepaint(_GanttPainter o) =>
      o.transform != transform ||
      o.baseDate != baseDate ||
      o.stats.length != stats.length ||
      o.predictions.length != predictions.length;
}
