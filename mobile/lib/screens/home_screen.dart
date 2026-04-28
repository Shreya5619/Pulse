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
                  const SizedBox(height: 24),
                  _buildBigSummaryCard(state),
                  const SizedBox(height: 24),
                  _buildRiskStack(state),
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
        Column(
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
        Row(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.calendar, size: 18, color: Colors.white30),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GanttScreen()),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.clock, size: 14, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Text(
                    "Client Review · 18 min",
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBigSummaryCard(AppState state) {
    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "3 risks forming in next 90 minutes",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip("Lateness", Colors.redAccent),
              _statusChip("Battery", Colors.orangeAccent),
              _statusChip("Overload", Colors.purpleAccent),
              _statusChip("Response Debt", Colors.blueAccent),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(LucideIcons.info, size: 12, color: Colors.white30),
              const SizedBox(width: 6),
              Text(
                "Tap a card below to see why.",
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white30),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRiskStack(AppState state) {
    return Column(
      children: [
        _riskCard(
          icon: LucideIcons.clock,
          color: Colors.redAccent,
          title: "You'll be 10–15 min late to client review",
          chips: ["Route congestion", "You leave in 5 min"],
          score: "0.78",
          level: "High",
        ),
        const SizedBox(height: 12),
        _riskCard(
          icon: LucideIcons.battery,
          color: Colors.orangeAccent,
          title: "Phone will die before commute ends",
          chips: ["Battery 17%", "Draining fast"],
          score: "0.82",
          level: "High",
        ),
        const SizedBox(height: 12),
        _riskCard(
          icon: LucideIcons.inbox,
          color: Colors.blueAccent,
          title: "4 pending responses to High priority",
          chips: ["Avg reply > 2h", "Client messages"],
          score: "0.45",
          level: "Med",
        ),
      ],
    );
  }

  Widget _riskCard({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> chips,
    required String score,
    required String level,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: chips.map((c) => _tinyChip(c)).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score,
                style: GoogleFonts.outfit(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                level,
                style: TextStyle(
                  color: color.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
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
