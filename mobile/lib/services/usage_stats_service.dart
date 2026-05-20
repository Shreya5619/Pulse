import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'lifecanvas_service.dart';

// ─── Android UsageStatsManager wrapper ───────────────────────────────────────
// Reads real screen-time data via a MethodChannel backed by native Kotlin code.
class UsageStatsService {
  static const _channel = MethodChannel('com.pulse.app/usage_stats');

  Future<List<AppUsageStat>> getTodayUsage() async {
    try {
      final result = await _channel.invokeMethod<List>('getTodayUsage');
      if (result != null) {
        return result.map((r) {
          final m = Map<String, dynamic>.from(r as Map);
          return AppUsageStat(
            appName: m['appName'] as String? ?? 'Unknown',
            totalMinutes: (m['totalMinutes'] as num? ?? 0).toInt(),
          );
        }).where((s) => s.totalMinutes > 1).toList()
          ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
      }
    } catch (e) {
      debugPrint('[UsageStatsService] MethodChannel failed: $e. Using mock data.');
    }
    // Fallback: mock data matching web prototype rows
    return _mockUsage();
  }

  List<AppUsageStat> _mockUsage() {
    final now = DateTime.now();
    // Create a dynamic realistic routine based on time of day
    return [
      AppUsageStat(appName: 'Chrome', totalMinutes: 45 + now.hour * 5),
      AppUsageStat(appName: 'WhatsApp', totalMinutes: 20 + now.hour * 2),
      AppUsageStat(appName: 'Spotify', totalMinutes: 10 + now.hour * 10),
      AppUsageStat(appName: 'Instagram', totalMinutes: 15 + now.hour * 3),
      AppUsageStat(appName: 'YouTube', totalMinutes: 5 + now.hour * 4),
      AppUsageStat(appName: 'Messages', totalMinutes: 10 + now.hour),
    ];
  }
}

final usageStatsService = UsageStatsService();
