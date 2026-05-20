import 'package:flutter/material.dart';

/// Shared coordinate system matching lifecanvas/app.js (Cytoscape Life Tree).
class LifeCanvasTimelineMath {
  LifeCanvasTimelineMath._();

  /// Web: graphX = 100 + hoursFromMidnight * 200
  static const double timeOriginX = 100.0;
  static const double pxPerHour = 200.0;

  /// Flutter canvas anchor (child space) — nodes render at anchor + graphX.
  static const double canvasAnchorX = 1000.0;
  static const double canvasAnchorY = 600.0;

  static double graphXFromHour(double hoursFromMidnight) =>
      timeOriginX + hoursFromMidnight * pxPerHour;

  static double hourFromDateTime(DateTime dt, DateTime baseDate) {
    final dayStart = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final ms = dt.difference(dayStart).inMilliseconds;
    return ms / 3600000.0;
  }

  static double nowHourOnDate(DateTime baseDate) {
    final now = DateTime.now();
    if (baseDate.year != now.year ||
        baseDate.month != now.month ||
        baseDate.day != now.day) {
      return 24.0;
    }
    return now.hour + now.minute / 60.0 + now.second / 3600.0;
  }

  static bool isViewingToday(DateTime baseDate) {
    final t = DateTime.now();
    return baseDate.year == t.year &&
        baseDate.month == t.month &&
        baseDate.day == t.day;
  }

  /// Child-space offset for a life event (matches web chrono position).
  static Offset eventPosition({
    required DateTime timestamp,
    required DateTime baseDate,
    required int laneIndex,
    required String nodeType,
    required double importance,
  }) {
    final h = hourFromDateTime(timestamp, baseDate);
    final graphX = graphXFromHour(h);
    double baseY = 300.0;
    if (nodeType == 'GOAL' || nodeType == 'INSIGHT') {
      baseY = 150.0 - importance * 50;
    } else {
      baseY = 450.0 + importance * 40;
    }
    final laneFlip = laneIndex.isEven ? -1.0 : 1.0;
    final y = baseY + laneFlip * (20.0 + (laneIndex % 4) * 18.0);
    return Offset(graphX, y);
  }

  /// Screen X for overlays (header, gantt, NOW) aligned with InteractiveViewer.
  static double screenXFromHour(double hour, Matrix4 transform) {
    final graphX = graphXFromHour(hour);
    final childX = canvasAnchorX + graphX;
    final scale = transform.getMaxScaleOnAxis();
    final tx = transform.getTranslation().x;
    return scale * childX + tx;
  }

  static bool isEventAfterNow(DateTime ts, DateTime baseDate) {
    if (!isViewingToday(baseDate)) return false;
    return ts.isAfter(DateTime.now());
  }

  static bool isTreeEventType(String type) =>
      type == 'LIFE_EVENT' ||
      type == 'EVENT' ||
      type == 'GOAL' ||
      type == 'HABIT' ||
      type == 'INSIGHT' ||
      type == 'MILESTONE';
}
