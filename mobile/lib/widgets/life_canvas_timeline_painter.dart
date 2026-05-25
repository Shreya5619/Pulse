import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/life_canvas_timeline_math.dart';

/// Timeline header ticks + NOW marker (synced with Life Tree pan/zoom).
class LifeCanvasTimelinePainter extends CustomPainter {
  final Matrix4 transform;
  final DateTime baseDate;
  final double viewportWidth;

  LifeCanvasTimelinePainter({
    required this.transform,
    required this.baseDate,
    required this.viewportWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = transform.getMaxScaleOnAxis();
    String mode;
    double stepHours;

    if (zoom > 4.0) {
      mode = 'MINUTE';
      stepHours = 5 / 60.0;
    } else if (zoom > 1.5) {
      mode = '15MIN';
      stepHours = 15 / 60.0;
    } else if (zoom > 0.6) {
      mode = 'HOUR';
      stepHours = 1.0;
    } else if (zoom > 0.2) {
      mode = '3HOUR';
      stepHours = 3.0;
    } else if (zoom > 0.1) {
      mode = '6HOUR';
      stepHours = 6.0;
    } else if (zoom > 0.05) {
      mode = '12HOUR';
      stepHours = 12.0;
    } else {
      mode = 'DAY';
      stepHours = 24.0;
    }

    final dayStart = DateTime(baseDate.year, baseDate.month, baseDate.day);

    double hourAtScreenX(double screenX) {
      final scale = transform.getMaxScaleOnAxis();
      final tx = transform.getTranslation().x;
      final childX = (screenX - tx) / scale;
      final graphX = childX - LifeCanvasTimelineMath.canvasAnchorX;
      return (graphX - LifeCanvasTimelineMath.timeOriginX) /
          LifeCanvasTimelineMath.pxPerHour;
    }

    final startH = hourAtScreenX(-20);
    final endH = hourAtScreenX(viewportWidth + 20);
    var currentH = (startH / stepHours).floorToDouble() * stepHours;

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    while (currentH <= endH) {
      final x = LifeCanvasTimelineMath.screenXFromHour(currentH, transform);
      if (x < -40 || x > size.width + 40) {
        currentH += stepHours;
        continue;
      }

      canvas.drawLine(
        Offset(x, size.height - 5),
        Offset(x, size.height),
        tickPaint,
      );

      final t = dayStart.add(
        Duration(milliseconds: (currentH * 3600000).round()),
      );
      String label;
      if (mode == 'MINUTE' || mode == '15MIN') {
        label =
            '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
      } else if (mode == 'HOUR' ||
          mode == '3HOUR' ||
          mode == '6HOUR' ||
          mode == '12HOUR') {
        label = '${t.hour}:00';
      } else {
        label = '${_weekday(t.weekday)} ${t.day}';
      }

      textPainter.text = TextSpan(
        text: label,
        style: GoogleFonts.jetBrainsMono(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 9,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, 4));

      currentH += stepHours;
    }

    if (LifeCanvasTimelineMath.isViewingToday(baseDate)) {
      final nowH = LifeCanvasTimelineMath.nowHourOnDate(baseDate);
      final nowX = LifeCanvasTimelineMath.screenXFromHour(nowH, transform);
      if (nowX >= 0 && nowX <= size.width) {
        canvas.drawLine(
          Offset(nowX, 0),
          Offset(nowX, size.height),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.65)
            ..strokeWidth = 1.0,
        );
        textPainter.text = TextSpan(
          text: 'NOW',
          style: GoogleFonts.jetBrainsMono(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(nowX + 3, size.height - 13),
        );
      }
    }
  }

  String _weekday(int w) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];

  @override
  bool shouldRepaint(LifeCanvasTimelinePainter o) =>
      o.transform != transform ||
      o.baseDate != baseDate ||
      o.viewportWidth != viewportWidth;
}

/// Full-height NOW line on the graph (web #nowBarOverlay).
class LifeCanvasNowBar extends StatelessWidget {
  final Matrix4 transform;
  final DateTime baseDate;

  const LifeCanvasNowBar({
    super.key,
    required this.transform,
    required this.baseDate,
  });

  @override
  Widget build(BuildContext context) {
    if (!LifeCanvasTimelineMath.isViewingToday(baseDate)) {
      return const SizedBox.shrink();
    }
    final nowH = LifeCanvasTimelineMath.nowHourOnDate(baseDate);
    final left = LifeCanvasTimelineMath.screenXFromHour(nowH, transform);
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4, left: 3),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'NOW',
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: 1,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
