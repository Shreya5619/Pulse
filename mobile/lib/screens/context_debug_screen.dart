import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_state.dart';
import '../models/device_context.dart';

class ContextDebugScreen extends StatelessWidget {
  const ContextDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          "Device Context",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final ctx = appState.deviceContext;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBatteryCard(ctx.battery),
                const SizedBox(height: 20),
                _buildLocationCard(ctx.location),
                const SizedBox(height: 20),
                _buildCalendarCard(ctx.upcomingEvents),
                const SizedBox(height: 20),
                _buildNotificationCard(ctx.notifications),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBatteryCard(BatteryInfo battery) {
    return _GlassCard(
      title: "Battery Status",
      icon: battery.isCharging
          ? LucideIcons.batteryCharging
          : LucideIcons.battery,
      color: _getBatteryColor(battery.level),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${battery.level}%",
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                battery.isCharging ? "Charging" : "Discharging",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 60,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: battery.trend
                        .asMap()
                        .entries
                        .map(
                          (e) => FlSpot(e.key.toDouble(), e.value.toDouble()),
                        )
                        .toList(),
                    isCurved: true,
                    color: _getBatteryColor(battery.level),
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _getBatteryColor(
                        battery.level,
                      ).withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(LocationInfo location) {
    return _GlassCard(
      title: "Location",
      icon: LucideIcons.mapPin,
      color: Colors.blueAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            location.status,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Lat: ${location.latitude.toStringAsFixed(4)}",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          Text(
            "Lng: ${location.longitude.toStringAsFixed(4)}",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(List<CalendarEvent> events) {
    return _GlassCard(
      title: "Calendar Slots",
      icon: LucideIcons.calendar,
      color: Colors.purpleAccent,
      child: events.isEmpty
          ? const Text(
              "No upcoming events",
              style: TextStyle(color: Colors.white54),
            )
          : Column(
              children: events
                  .take(3)
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "${DateFormat.Hm().format(e.start)} - ${DateFormat.Hm().format(e.end)}",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildNotificationCard(List<NotificationInfo> notifications) {
    final counts = <String, int>{};
    for (var n in notifications) {
      counts[n.packageName] = (counts[n.packageName] ?? 0) + 1;
    }

    return _GlassCard(
      title: "Recent Notifications",
      icon: LucideIcons.bell,
      color: Colors.orangeAccent,
      child: notifications.isEmpty
          ? const Text(
              "No notifications detected",
              style: TextStyle(color: Colors.white54),
            )
          : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total: ${notifications.length}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      "Apps: ${counts.length}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 20),
                ...notifications
                    .take(5)
                    .map(
                      (n) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          n.packageName.split('.').last,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          n.title ?? "No title",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Text(
                          DateFormat.Hm().format(n.timestamp),
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level > 60) return Colors.greenAccent;
    if (level > 20) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

class _GlassCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color color;

  const _GlassCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
