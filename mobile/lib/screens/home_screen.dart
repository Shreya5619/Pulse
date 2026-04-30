import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../widgets/glass_card.dart';
import '../theme/colors.dart';
import '../screens/context_debug_screen.dart';
import '../screens/replay_screen.dart';
import '../screens/scenario_player_screen.dart';
import '../screens/gantt_screen.dart';
import '../widgets/risk_hero_card.dart';
import '../models/risk_snapshot.dart';
import '../models/risk_state.dart' as legacy;
import '../screens/graph_explanation_screen.dart';
import '../widgets/route_eta_strip.dart';


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
                  const RouteEtaStrip(),
                  const SizedBox(height: 16),
                  _buildFuturesPathLabel(state),
                  const SizedBox(height: 24),
                  const RiskHeroCard(),
                  const SizedBox(height: 24),

                  _buildRiskStack(context, state),
                  const SizedBox(height: 24),
                  _buildContextChipsRow(context, state),
                  const SizedBox(height: 80), // Space for bottom banner
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderStrip(BuildContext context, AppState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Now until 90 min",
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
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
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.calendar, size: 18, color: Colors.white30),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GanttScreen()),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.clock, size: 14, color: Colors.blueAccent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "Client Review · 18 min",
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
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
            style: GoogleFonts.outfit(fontSize: 11, color: color, fontWeight: FontWeight.bold),
          ),
          const Text(
            " path",
            style: TextStyle(fontSize: 11, color: Colors.white30),
          ),
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
      children: risks.map((risk) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _riskCard(
          risk: risk,
          state: state,
          onTap: () => _showExplanation(context, state, risk),
        ),
      )).toList(),
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
      case RiskType.lateness: icon = LucideIcons.clock; break;
      case RiskType.battery: icon = LucideIcons.battery; break;
      case RiskType.responseDebt: icon = LucideIcons.inbox; break;
      case RiskType.overload: icon = LucideIcons.alertTriangle; break;
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
                color: risk.color.withOpacity(0.1),
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
                        style: GoogleFonts.outfit(fontSize: 10, color: Colors.redAccent.withOpacity(0.8)),
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
                  risk.score.toStringAsFixed(2),
                  style: GoogleFonts.outfit(
                    color: risk.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  risk.label.name.toUpperCase(),
                  style: TextStyle(
                    color: risk.color.withOpacity(0.5),
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
        color: Colors.white.withOpacity(0.05),
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
              _contextChip(LucideIcons.battery, "Battery 17% (draining fast)"),
              _contextChip(LucideIcons.calendar, "Calendar: 3 events next 2h"),
              _contextChip(LucideIcons.bell, "Notifications: 46 in last hour"),
              _contextChip(
                LucideIcons.mapPin,
                "Koramangala → Whitefield · 56 min",
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
            label: const Text("VIEW RAW CONTEXT STREAM", style: TextStyle(fontSize: 10, letterSpacing: 1.1)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white30,
              side: const BorderSide(color: Colors.white10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contextChip(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.white30),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
