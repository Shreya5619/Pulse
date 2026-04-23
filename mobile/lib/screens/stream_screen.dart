import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../widgets/glass_card.dart';
import '../theme/colors.dart';

class StreamScreen extends StatelessWidget {
  const StreamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final snapshots = state.snapshots;
        final latest = snapshots.isNotEmpty ? snapshots.first : null;
        
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Context Stream",
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "Real-time signal analysis",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  if (latest != null) ...[
                    _buildSnapshotSummary(latest),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildDeviceBox(latest)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildLocationBox(latest)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildCalendarBox(latest)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildNotificationBox(latest)),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  Text(
                    "Raw Event Feed",
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildEventFeed(snapshots),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSnapshotSummary(dynamic snap) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Snapshot ID", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Text(snap.id.substring(0, 8), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          _buildRow("Timestamp", DateFormat('HH:mm:ss').format(snap.timestamp)),
          _buildRow("User ID", "arjun_dev_01"),
          _buildRow("Source", "System Sensor v2.0"),
        ],
      ),
    );
  }

  Widget _buildDeviceBox(dynamic snap) {
    return GlassCard(
      height: 120,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.smartphone, size: 18, color: AppColors.primary),
          const Spacer(),
          Text("${snap.batteryLevel.toInt()}%", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(snap.isCharging ? "Charging" : "On Battery", style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildLocationBox(dynamic snap) {
    return GlassCard(
      height: 120,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.mapPin, size: 18, color: AppColors.electricBlue),
          const Spacer(),
          Text(snap.location, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
          Text(snap.activity, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCalendarBox(dynamic snap) {
    return GlassCard(
      height: 120,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.calendar, size: 18, color: AppColors.warning),
          const Spacer(),
          Text(snap.nextEvent, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
          const Text("Next Event", style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildNotificationBox(dynamic snap) {
    return GlassCard(
      height: 120,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.bell, size: 18, color: AppColors.danger),
          const Spacer(),
          Text("${(snap.recentSignals as List).length} Alerts", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const Text("Recent Signals", style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEventFeed(List snapshots) {
    return Column(
      children: snapshots.map((s) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Snapshot Updated", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("Location: ${s.location} • Battery: ${s.batteryLevel.toInt()}%", style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ),
            Text(DateFormat('HH:mm:ss').format(s.timestamp), style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
