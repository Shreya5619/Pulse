import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../widgets/glass_card.dart';
import '../theme/colors.dart';
import '../screens/context_debug_screen.dart';
import '../screens/scenario_player_screen.dart';
import '../screens/gantt_screen.dart';
import '../widgets/risk_hero_card.dart';

import '../models/risk_snapshot.dart';
import '../screens/graph_explanation_screen.dart';
import '../screens/multi_mode_eta_screen.dart';
import '../screens/twin_graph_screen.dart';
import '../screens/timeline_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final risk = state.currentRisk;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderStrip(context, state),
                  const SizedBox(height: 16),
                  _buildFuturesPathLabel(state),
                  const SizedBox(height: 24),
                  RiskHeroCard(),
                  const SizedBox(height: 24),
                  _buildRiskStack(context, state),
                  const SizedBox(height: 24),
                  _buildContextChipsRow(context, state),
                  const SizedBox(height: 24),
                  _buildSystemIntegration(context, state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemIntegration(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "System Integration",
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.white30,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _integrationButton(
                icon: LucideIcons.bellRing,
                label: "Notification Access",
                onPressed: () => state.openNotificationSettings(),
              ),
              const SizedBox(height: 12),
              _integrationButton(
                icon: LucideIcons.battery,
                label: "Disable Battery Optimization",
                onPressed: () => state.requestBatteryOptimizationDisable(),
              ),
              const SizedBox(height: 12),
              _integrationButton(
                icon: LucideIcons.layers,
                label: "System Overlay",
                onPressed: () => state.requestOverlayPermission(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _integrationButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          foregroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildHeaderStrip(BuildContext context, AppState state) {
    final battery = state.deviceContext.battery;
    String modeText = "Normal";
    IconData batteryIcon = LucideIcons.battery;
    Color batteryColor = Colors.white30;

    if (battery.isCharging) {
      modeText = "Charging";
      batteryIcon = LucideIcons.batteryCharging;
      batteryColor = AppColors.success;
    } else if (battery.isInBatterySaveMode) {
      modeText = "Battery Saver";
      batteryIcon = LucideIcons.batteryLow;
      batteryColor = Colors.orangeAccent;
    } else if (battery.level < 20) {
      modeText = "Low";
      batteryIcon = LucideIcons.batteryLow;
      batteryColor = AppColors.danger;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(batteryIcon, size: 14, color: batteryColor),
                const SizedBox(width: 6),
                Text(
                  "${battery.level}% • $modeText",
                  style: GoogleFonts.outfit(
                    color: batteryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  LucideIcons.playCircle,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ScenarioPlayerScreen(),
                    ),
                  ),
                  child: const Text(
                    "Simulation Mode",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                LucideIcons.mapPin,
                size: 18,
                color: Colors.white30,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MultiModeEtaScreen(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                LucideIcons.calendar,
                size: 18,
                color: Colors.white30,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GanttScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(
                LucideIcons.list,
                size: 18,
                color: Colors.white30,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TimelineScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(
                LucideIcons.gitBranch,
                size: 18,
                color: Colors.white30,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TwinGraphScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFuturesPathLabel(AppState state) {
    String title = "Recommended";
    Color color = AppColors.primary;
    if (state.selectedScenarioId == "DO_NOTHING") {
      title = "Do Nothing";
      color = AppColors.danger;
    } else if (state.selectedScenarioId == "ALTERNATE") {
      title = "Alternate path";
      color = Colors.orangeAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.sparkles, size: 14, color: color),
          const SizedBox(width: 10),
          Text(
            "Futures: Currently on ",
            style: GoogleFonts.outfit(fontSize: 11, color: Colors.white30),
          ),
          Text(
            "'$title'",
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            " path",
            style: TextStyle(fontSize: 11, color: Colors.white30),
          ),
        ],
      ),
    );
  }

  Widget _miniRiskBadge(
    IconData icon,
    String text, {
    Color color = Colors.white30,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.outfit(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  Widget _buildRiskStack(BuildContext context, AppState state) {
    final risks = state.currentRiskSnapshot?.risks ?? [];
    if (risks.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        width: double.infinity,
        child: Center(
          child: Text(
            "No active risks detected",
            style: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: risks
          .map(
            (risk) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _riskCard(
                risk: risk,
                state: state,
                onTap: () => _showExplanation(context, state, risk),
              ),
            ),
          )
          .toList(),
    );
  }

  void _showExplanation(BuildContext context, AppState state, RiskScore risk) {
    if (risk.nodeId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GraphExplanationScreen(
            nodeId: risk.nodeId!,
            riskType: risk.type.name,
          ),
        ),
      );
    }
  }

  Widget _riskCard({
    required RiskScore risk,
    required AppState state,
    required VoidCallback onTap,
  }) {
    IconData icon;
    switch (risk.type) {
      case RiskType.lateness:
        icon = LucideIcons.clock;
        break;
      case RiskType.battery:
        icon = LucideIcons.battery;
        break;
      case RiskType.responseDebt:
        icon = LucideIcons.inbox;
        break;
      case RiskType.overload:
        icon = LucideIcons.alertTriangle;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: risk.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: risk.color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    risk.summary,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (risk.type == RiskType.lateness && state.etaInfo.hasRoute)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Current route ETA ${state.etaInfo.etaDisplay} · you'll be ${state.etaInfo.leaveInMinutes != null && state.etaInfo.leaveInMinutes! < 0 ? state.etaInfo.leaveInMinutes!.abs() : 0} min late.",
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: Colors.redAccent.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: risk.causes.map((c) => _tinyChip(c)).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  risk.score.toStringAsFixed(1),
                  style: GoogleFonts.outfit(
                    color: risk.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  risk.label.name.toUpperCase(),
                  style: TextStyle(
                    color: risk.color.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tinyChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        "• $label",
        style: const TextStyle(color: Colors.white54, fontSize: 9),
      ),
    );
  }

  Widget _buildContextChipsRow(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Current Context",
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.white30,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _contextChip(
                state.deviceContext.battery.isCharging
                    ? LucideIcons.batteryCharging
                    : (state.deviceContext.battery.isInBatterySaveMode
                          ? LucideIcons.batteryLow
                          : LucideIcons.battery),
                "Battery ${state.deviceContext.battery.level}% (${state.deviceContext.battery.isCharging ? 'Charging' : (state.deviceContext.battery.isInBatterySaveMode ? 'Saver' : 'Normal')})",
                color: state.deviceContext.battery.isCharging
                    ? AppColors.success
                    : (state.deviceContext.battery.isInBatterySaveMode
                          ? Colors.orangeAccent
                          : null),
              ),
              _contextChip(
                LucideIcons.calendar,
                "Calendar: ${state.deviceContext.upcomingEvents.length} events next 2h",
              ),
              _contextChip(
                LucideIcons.bell,
                "Notifications: ${state.deviceContext.notifications.length} recent",
              ),
              _contextChip(
                LucideIcons.mapPin,
                state.etaInfo.hasRoute
                    ? "${state.etaInfo.destinationName} · ${state.etaInfo.etaDisplay}"
                    : "Location: ${state.deviceContext.location.status}",
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContextDebugScreen(),
                ),
              );
            },
            icon: const Icon(LucideIcons.list, size: 14),
            label: const Text(
              "VIEW RAW CONTEXT STREAM",
              style: TextStyle(fontSize: 10, letterSpacing: 1.1),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white30,
              side: const BorderSide(color: Colors.white10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contextChip(IconData icon, String label, {Color? color}) {
    final displayColor = color ?? Colors.white30;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: displayColor.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: displayColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color ?? Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
