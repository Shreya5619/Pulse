import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/app_state.dart';
import '../widgets/pulse_gauge.dart';
import '../widgets/glass_card.dart';
import '../theme/colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final risk = state.currentRisk;
        
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: AppColors.surfaceGradient,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 40),
                    Center(
                      child: PulseGauge(
                        score: risk.score,
                        status: risk.levelText,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildReasonBox(context, risk.reasons),
                    const SizedBox(height: 20),
                    _buildTrendBox(context, risk.history),
                    const SizedBox(height: 20),
                    _buildActionBox(context, state),
                    const SizedBox(height: 20),
                    _buildConnectionBox(context, state),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Good Morning, Arjun",
          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 4),
        Text(
          "Here's your day, optimized.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildReasonBox(BuildContext context, List<String> reasons) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertTriangle, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Text("Detection Summary", style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          ...reasons.map((reason) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(LucideIcons.circle, size: 6, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Text(reason, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildTrendBox(BuildContext context, List<double> history) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Risk Trend", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: history.map((h) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Text(
                h.toInt().toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBox(BuildContext context, AppState state) {
    return GlassCard(
      borderColor: AppColors.primary.withOpacity(0.3),
      padding: const EdgeInsets.all(2),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [AppColors.primary.withOpacity(0.1), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(LucideIcons.check, color: Colors.black),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Quick Check-in", style: Theme.of(context).textTheme.titleMedium),
                  Text("Confirm you're safe to lower risk score.", style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBox(BuildContext context, AppState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatTile(
          context,
          "Status",
          state.isLive ? "Live" : "Mock",
          state.isLive ? AppColors.success : AppColors.warning,
        ),
        _buildStatTile(
          context,
          "Signals",
          state.snapshots.length.toString(),
          AppColors.primary,
        ),
        _buildStatTile(
          context,
          "Server",
          "Connected",
          AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStatTile(BuildContext context, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
