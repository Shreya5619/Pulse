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

class GanttBarSpan {
  final double startH;
  final double endH;
  GanttBarSpan(this.startH, this.endH);
}

class _GanttPainter extends CustomPainter {
  final List<AppUsageStat> stats;
  final List<PredictedEvent> predictions;
  final Matrix4 transform;
  final DateTime baseDate;

  // Dynamically populated list of top apps
  final List<String> ganttApps = [];

  _GanttPainter({
    required this.stats,
    required this.predictions,
    required this.transform,
    required this.baseDate,
  }) {
    // Sort stats by totalMinutes descending and extract top app names
    final sorted = List<AppUsageStat>.from(stats)
      ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
    for (final s in sorted) {
      if (!ganttApps.contains(s.appName)) {
        ganttApps.add(s.appName);
      }
    }
    // Pad with standard apps up to 8 rows if needed
    const defaults = ['Screen', 'Messages', 'Chrome', 'Instagram', 'YouTube', 'WhatsApp', 'Spotify'];
    for (final d in defaults) {
      if (ganttApps.length >= 8) break;
      if (!ganttApps.contains(d)) {
        ganttApps.add(d);
      }
    }
  }

  static const _labelW = 56.0;
  static const _rowH = 14.0;
  static const _rowGap = 2.0;

  Color _getAppColor(String appName, int index) {
    final predefined = {
      'Screen': const Color(0xFF64FFDA),
      'Messages': const Color(0xFF4ADE80),
      'Chrome': const Color(0xFF60A5FA),
      'Instagram': const Color(0xFFA78BFA),
      'YouTube': const Color(0xFFE57373),
      'WhatsApp': const Color(0xFF64B5F6),
      'Spotify': const Color(0xFF81C784),
    };
    if (predefined.containsKey(appName)) return predefined[appName]!;
    final colors = [
      const Color(0xFF00E5FF),
      const Color(0xFFBF5AF2),
      const Color(0xFFFFB300),
      const Color(0xFF4EE2C9),
      const Color(0xFF0A84FF),
      const Color(0xFFFF5252),
    ];
    return colors[index % colors.length];
  }

  double _hourToScreenX(double h, double width) {
    final x = LifeCanvasTimelineMath.screenXFromHour(h, transform);
    return x.clamp(_labelW, width);
  }

  int _rowForApp(String name) {
    for (var i = 0; i < ganttApps.length; i++) {
      if (ganttApps[i].toLowerCase() == name.toLowerCase()) return i;
    }
    return name.hashCode.abs() % ganttApps.length;
  }

  List<GanttBarSpan> _distributeSegments(int hour, double minutes) {
    if (minutes <= 0) return [];
    if (minutes >= 55) return [GanttBarSpan(hour.toDouble(), hour + 1.0)];

    final spans = <GanttBarSpan>[];
    if (minutes < 15) {
      final start = hour + 0.3;
      final end = start + minutes / 60.0;
      spans.add(GanttBarSpan(start, end));
    } else if (minutes < 35) {
      final half = minutes / 2;
      final start1 = hour + 0.15;
      final end1 = start1 + half / 60.0;
      final start2 = hour + 0.6;
      final end2 = start2 + half / 60.0;
      spans.add(GanttBarSpan(start1, end1));
      spans.add(GanttBarSpan(start2, end2));
    } else {
      final third = minutes / 3;
      final start1 = hour + 0.05;
      final end1 = start1 + third / 60.0;
      final start2 = hour + 0.4;
      final end2 = start2 + third / 60.0;
      final start3 = hour + 0.75;
      final end3 = start3 + third / 60.0;
      spans.add(GanttBarSpan(start1, end1));
      spans.add(GanttBarSpan(start2, end2));
      spans.add(GanttBarSpan(start3, end3));
    }
    return spans;
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

    for (var i = 0; i < ganttApps.length; i++) {
      final y = i * (_rowH + _rowGap) + 6.0;
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(_labelW, y, size.width - _labelW, _rowH),
          Paint()..color = Colors.white.withValues(alpha: 0.015),
        );
      }
      labelPaint
        ..text = TextSpan(
          text: ganttApps[i],
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
      final c = _getAppColor(stat.appName, rowIdx);

      if (stat.hourlySegments.isNotEmpty) {
        for (final seg in stat.hourlySegments) {
          final startH = seg.hour.toDouble();
          if (isToday && startH >= nowH) continue;
          
          final spans = _distributeSegments(seg.hour, seg.minutes);
          for (final span in spans) {
            var endH = span.endH;
            if (isToday) endH = math.min(endH, nowH);
            if (endH <= span.startH) continue;

            final x1 = math.max(_hourToScreenX(span.startH, size.width), _labelW);
            final x2 = _hourToScreenX(endH, size.width);
            final w = x2 - x1;
            if (w < 1.0) continue;

            barPaint.color = c.withValues(alpha: stat.appName == 'Screen' ? 0.35 : 0.7);
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x1, y + 1, math.max(w, 1.5), _rowH - 2),
                const Radius.circular(3),
              ),
              barPaint,
            );
          }
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
      final rowIdx = _rowForApp(app);
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
