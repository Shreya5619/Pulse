import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Timeline Header & "NOW" Bar Painter ──────────────────────────────────────
class LifeCanvasTimelinePainter extends CustomPainter {
  final double viewOffsetHours;
  final double zoomScale;
  final DateTime baseDate;

  LifeCanvasTimelinePainter({
    required this.viewOffsetHours,
    required this.zoomScale,
    required this.baseDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Determine zoom tier to set step size and label format
    String mode;
    double stepHours;

    if (zoomScale > 4.0) { mode = 'MINUTE'; stepHours = 5 / 60.0; }
    else if (zoomScale > 1.5) { mode = '15MIN'; stepHours = 15 / 60.0; }
    else if (zoomScale > 0.6) { mode = 'HOUR'; stepHours = 1.0; }
    else if (zoomScale > 0.2) { mode = '3HOUR'; stepHours = 3.0; }
    else if (zoomScale > 0.1) { mode = '6HOUR'; stepHours = 6.0; }
    else if (zoomScale > 0.05) { mode = '12HOUR'; stepHours = 12.0; }
    else if (zoomScale > 0.015) { mode = 'DAY'; stepHours = 24.0; }
    else if (zoomScale > 0.004) { mode = 'WEEK'; stepHours = 7 * 24.0; }
    else if (zoomScale > 0.001) { mode = 'MONTH'; stepHours = 30 * 24.0; }
    else { mode = 'YEAR'; stepHours = 365 * 24.0; }

    final startOfTodayMs = DateTime(baseDate.year, baseDate.month, baseDate.day).millisecondsSinceEpoch;

    // Convert pixel to hour offset
    double pxToHour(double px) => (px / zoomScale) / 200.0 + viewOffsetHours - (100.0 / 200.0);
    // Convert hour offset to pixel
    double hourToPx(double h) => ((h - viewOffsetHours + (100.0 / 200.0)) * 200.0) * zoomScale;

    final startH = pxToHour(-50);
    final endH = pxToHour(size.width + 50);

    // Snap to nearest step
    double currentH = (startH / stepHours).floorToDouble() * stepHours;

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    while (currentH <= endH) {
      final x = hourToPx(currentH);
      final ms = startOfTodayMs + (currentH * 3600000).toInt();
      final t = DateTime.fromMillisecondsSinceEpoch(ms);

      // Draw Tick
      canvas.drawLine(Offset(x, size.height - 5), Offset(x, size.height), tickPaint);

      // Label text
      String label;
      if (mode == 'MINUTE' || mode == '15MIN') { label = '${t.hour}:${t.minute.toString().padLeft(2, '0')}'; }
      else if (mode == 'HOUR' || mode == '3HOUR' || mode == '6HOUR' || mode == '12HOUR') { label = '${t.hour}:00'; }
      else if (mode == 'DAY') { label = '${_weekday(t.weekday)} ${t.day}'; }
      else if (mode == 'WEEK') { label = 'W${(t.day / 7).ceil()} (${_month(t.month)})'; }
      else if (mode == 'MONTH') { label = '${_month(t.month)} ${t.year.toString().substring(2)}'; }
      else { label = '${t.year}'; }

      textPainter.text = TextSpan(
        text: label,
        style: GoogleFonts.jetBrainsMono(color: Colors.white.withValues(alpha: 0.5), fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, 4));

      currentH += stepHours;
    }

    // 2. Draw vertical "NOW" bar mapping present moment
    final today = DateTime.now();
    final isToday = baseDate.year == today.year && baseDate.month == today.month && baseDate.day == today.day;
    if (isToday) {
      final nowH = today.hour + today.minute / 60.0 + today.second / 3600.0;
      final nowX = hourToPx(nowH);
      if (nowX >= 0 && nowX <= size.width) {
        final nowPaint = Paint()
          ..color = Colors.redAccent.withValues(alpha: 0.6)
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(nowX, 0), Offset(nowX, size.height), nowPaint);
        
        textPainter.text = TextSpan(
          text: 'NOW',
          style: GoogleFonts.jetBrainsMono(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(nowX - textPainter.width / 2, size.height - 13));
      }
    }
  }

  String _weekday(int w) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
  String _month(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  @override
  bool shouldRepaint(LifeCanvasTimelinePainter o) =>
      o.viewOffsetHours != viewOffsetHours || o.zoomScale != zoomScale || o.baseDate != baseDate;
}
