import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
        
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: AppColors.surfaceGradient,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: snapshots.length,
                      itemBuilder: (context, index) {
                        final snap = snapshots[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildSnapshotCard(context, snap),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Context Stream",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                "Real-time signal analysis",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.radio, size: 14, color: AppColors.primary),
                SizedBox(width: 6),
                Text("LIVE", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotCard(BuildContext context, dynamic snap) {
    return GlassCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withOpacity(0.5),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('HH:mm:ss').format(snap.timestamp),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                Text(
                  snap.id.substring(0, 8),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSignalRow(LucideIcons.battery, "Battery", "${snap.batteryLevel.toInt()}%", snap.isCharging ? AppColors.success : AppColors.textPrimary),
                const Divider(height: 20, color: AppColors.textMuted),
                _buildSignalRow(LucideIcons.mapPin, "Location", snap.location, AppColors.textPrimary),
                const Divider(height: 20, color: AppColors.textMuted),
                _buildSignalRow(LucideIcons.activity, "Activity", snap.activity, AppColors.secondary),
                const Divider(height: 20, color: AppColors.textMuted),
                _buildSignalRow(LucideIcons.calendar, "Next Event", snap.nextEvent, AppColors.textPrimary),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (snap.recentSignals as List<String>).map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(s, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalRow(IconData icon, String label, String value, Color valueColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const Spacer(),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w500, fontSize: 14)),
      ],
    );
  }
}
