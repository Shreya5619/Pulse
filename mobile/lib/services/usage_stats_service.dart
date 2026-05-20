import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'lifecanvas_service.dart';

// ─── Android UsageStatsManager wrapper ───────────────────────────────────────
// Reads real screen-time data via a MethodChannel backed by native Kotlin code.
class UsageStatsService {
  static const _channel = MethodChannel('com.pulse.app/usage_stats');

  Future<List<AppUsageStat>> getTodayUsage() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return getUsageForDay(today);
  }

  /// [dateYmd] is `yyyy-MM-dd` in local time. Uses hourly UsageEvents when permission granted.
  Future<List<AppUsageStat>> getUsageForDay(String dateYmd) async {
    final day = DateTime.tryParse('${dateYmd}T00:00:00');
    final startMs = (day ?? DateTime.now()).millisecondsSinceEpoch;

    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getHourlyUsageForDay',
        {'dayStartMs': startMs},
      );
      if (result != null && result.isNotEmpty) {
        return result.map((r) {
          final m = Map<String, dynamic>.from(r as Map);
          final segsRaw = m['hourlySegments'] as List? ?? [];
          final segs = segsRaw
              .map((e) => AppUsageHourSegment.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          return AppUsageStat(
            appName: m['appName'] as String? ?? 'Unknown',
            totalMinutes: (m['totalMinutes'] as num? ?? 0).toInt(),
            hourlySegments: segs,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[UsageStatsService] getHourlyUsageForDay failed: $e. Trying aggregate getTodayUsage.');
    }

    if (_isSameLocalDay(dateYmd, DateTime.now())) {
      try {
        final result = await _channel.invokeMethod<List>('getTodayUsage');
        if (result != null) {
          return result.map((r) {
            final m = Map<String, dynamic>.from(r as Map);
            return AppUsageStat(
              appName: m['appName'] as String? ?? 'Unknown',
              totalMinutes: (m['totalMinutes'] as num? ?? 0).toInt(),
              hourlySegments: const [],
            );
          }).where((s) => s.totalMinutes > 1).toList()
            ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
        }
      } catch (e) {
        debugPrint('[UsageStatsService] getTodayUsage failed: $e');
      }
    }

    return _mockUsageForDay(dateYmd);
  }

  bool _isSameLocalDay(String ymd, DateTime d) {
    final p = ymd.split('-');
    if (p.length != 3) return false;
    return d.year == int.parse(p[0]) && d.month == int.parse(p[1]) && d.day == int.parse(p[2]);
  }

  List<AppUsageStat> _mockUsageForDay(String dateYmd) {
    final now = DateTime.now();
    final sameDay = _isSameLocalDay(dateYmd, now);
    final capH = sameDay ? now.hour : 23;
    final rows = <AppUsageStat>[];
    const apps = ['Chrome', 'WhatsApp', 'Spotify', 'Instagram', 'YouTube', 'Messages'];
    for (var i = 0; i < apps.length; i++) {
      final segs = <AppUsageHourSegment>[];
      for (var h = 8; h <= capH; h += 2) {
        segs.add(AppUsageHourSegment(hour: h, minutes: 4.0 + (i + h % 5) * 1.2));
      }
      final total = segs.fold<double>(0, (a, s) => a + s.minutes).round();
      rows.add(AppUsageStat(appName: apps[i], totalMinutes: total, hourlySegments: segs));
    }
    rows.sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
    return rows.take(6).toList();
  }
}

final usageStatsService = UsageStatsService();
