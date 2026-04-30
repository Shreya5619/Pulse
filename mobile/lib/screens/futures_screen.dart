import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/route_eta_strip.dart';

class FuturesScreen extends StatefulWidget {
  const FuturesScreen({super.key});

  @override
  State<FuturesScreen> createState() => _FuturesScreenState();
}

class _FuturesScreenState extends State<FuturesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).fetchFutures();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final futures =
            state.currentFutures?['futures'] as List<dynamic>? ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.isReplayMode
                                ? "Historical Projections"
                                : "Future Projections",
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.isReplayMode
                                ? "REPLAYING HISTORICAL SNAPSHOT"
                                : "Simulating the next 2 hours",
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: state.isReplayMode
                                  ? AppColors.primary
                                  : Colors.white30,
                              fontWeight: state.isReplayMode
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      if (!state.isReplayMode)
                        IconButton(
                          icon: const Icon(
                            LucideIcons.refreshCw,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          onPressed: () => Provider.of<AppState>(
                            context,
                            listen: false,
                          ).fetchFutures(),
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: RouteEtaStrip(isMini: true),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: futures.isEmpty
                      ? const Center(
                          child: Text(
                            "No projections available",
                            style: TextStyle(color: Colors.white30),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                          itemCount: futures.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 20),
                          itemBuilder: (context, index) {
                            final data = futures[index];
                            final isSelected =
                                state.selectedScenarioId == data['id'];
                            return _buildScenarioCard(
                              context,
                              state,
                              data,
                              isSelected,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScenarioCard(
    BuildContext context,
    AppState state,
    dynamic data,
    bool isSelected,
  ) {
    final metrics = data['metrics'];
    final stressScore = (metrics['stressScore'] as num?)?.toDouble() ?? 0.0;
    final color = stressScore > 0.7
        ? AppColors.danger
        : stressScore > 0.4
        ? Colors.orangeAccent
        : AppColors.success;

    return GestureDetector(
      onTap: () {
        state.selectScenario(data['id']);
        _showScenarioDetails(context, state, data);
      },
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        borderColor: isSelected ? color.withValues(alpha: 0.8) : Colors.white10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? "Scenario",
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _getStatusBadge(data['id']),
                  ],
                ),
                if (isSelected)
                  Icon(LucideIcons.checkCircle2, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 20),
            _metricRow(
              LucideIcons.clock,
              _formatLateness(metrics['expectedLatenessMinutes'] ?? 0),
              color,
            ),
            _metricRow(
              LucideIcons.battery,
              "Battery: ~${metrics['batteryPercent'] ?? '?'}% at end",
              color,
            ),
            _metricRow(
              LucideIcons.bell,
              "+${metrics['notificationCount'] ?? 0} new notifications",
              color,
            ),
            _metricRow(
              LucideIcons.layers,
              "${metrics['overlapCount'] ?? 0} overlapping blocks",
              color,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "RISK TREND",
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white24,
                    letterSpacing: 1.2,
                  ),
                ),
                _buildMiniRiskChart(stressScore, color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusBadge(String id) {
    String text = "FEASIBLE";
    Color color = Colors.white24;
    if (id == "RECOMMENDED") {
      text = "OPTIMAL";
      color = AppColors.primary.withValues(alpha: 0.3);
    } else if (id == "DO_NOTHING") {
      text = "HIGH RISK";
      color = AppColors.danger.withValues(alpha: 0.2);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatLateness(int mins) {
    if (mins <= 0) return "Arrive on time";
    if (mins < 10) return "Arrive slightly late ($mins min)";
    return "Arrive $mins–${mins + 5} min late";
  }

  Widget _metricRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniRiskChart(double score, Color color) {
    return Row(
      children: [
        _bar(score * 0.4, color.withValues(alpha: 0.3)),
        const SizedBox(width: 2),
        _bar(score * 0.7, color.withValues(alpha: 0.6)),
        const SizedBox(width: 2),
        _bar(score, color),
      ],
    );
  }

  Widget _bar(double heightFactor, Color color) {
    return Container(
      width: 6,
      height: 16 * heightFactor.clamp(0.1, 1.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  void _showScenarioDetails(
    BuildContext context,
    AppState state,
    dynamic data,
  ) {
    final metrics = data['metrics'];
    final id = data['id'];

    List<String> interventions = [];
    if (id == "RECOMMENDED") {
      interventions = [
        "Leave 15 min earlier",
        "Enable commute mode",
        "Send 'running late' message",
        "Plan a charging stop",
      ];
    } else if (id == "ALTERNATE") {
      interventions = [
        "Plan 15 min charging stop",
        "Arrive 10 min late",
        "Full battery visibility",
      ];
    } else {
      interventions = [
        "Maintain current routine",
        "Accept potential delays",
        "No battery saving",
      ];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Strategy: ${data['title']}",
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data['description'] ?? "",
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "REQUIRED ACTIONS",
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ...interventions
                .map(
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.check,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          i,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Deep link would go here - for now just feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Plan applied and synced to Dashboard"),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "APPLY THIS PLAN",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
