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
    final metrics = data['metrics'] ?? {};
    final stressScore = (metrics['stressScore'] as num?)?.toDouble() ?? 0.0;
    final color = stressScore > 0.7
        ? AppColors.danger
        : stressScore > 0.4
        ? Colors.orangeAccent
        : AppColors.success;

    final lateness = metrics['expectedLatenessMinutes'] ?? 0;
    final eta = metrics['etaMinutes'] ?? 0;
    final battery = metrics['batteryPercent'] ?? 0;
    final notifs = metrics['notificationCount'] ?? 0;
    final overlaps = metrics['overlapCount'] ?? 0;
    final transport = metrics['transportMode'];

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
                Expanded(
                  child: Column(
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
                      const SizedBox(height: 4),
                      Text(
                        data['description'] ?? "",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white38,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _getStatusBadge(data['id']),
                    if (isSelected) ...[
                      const SizedBox(height: 8),
                      Icon(LucideIcons.checkCircle2, color: color, size: 20),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (lateness > 0 || eta > 0)
              _metricRow(
                LucideIcons.clock,
                lateness > 0 ? _formatLateness(lateness) : "ETA: $eta min",
                color,
              ),
            if (transport != null)
              _metricRow(LucideIcons.car, "Via: $transport", color),
            if ((metrics['missedCommitments'] ?? 0) > 0)
              _metricRow(
                LucideIcons.calendarX,
                "${metrics['missedCommitments']} missed commitments",
                AppColors.danger,
              ),
            _metricRow(
              LucideIcons.battery,
              "Battery level: ~$battery% remaining",
              color,
            ),
            if (notifs > 0)
              _metricRow(LucideIcons.bell, "+$notifs new notifications", color),
            if (overlaps > 0)
              _metricRow(
                LucideIcons.layers,
                "$overlaps overlapping blocks",
                color,
              ),
            if (metrics['alternateModes'] != null &&
                (metrics['alternateModes'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ALTERNATE OPTIONS",
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white24,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (metrics['alternateModes'] as List).map((m) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getModeIcon(m['mode'] ?? ""),
                                size: 12,
                                color: color.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${m['mode']}: ${m['etaMinutes']}m",
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "STRESS IMPACT",
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
    if (mins < 5) return "Minor delay ($mins min)";
    if (mins < 15) return "Lateness: $mins min";
    return "Significant delay ($mins+ min)";
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
    final risks = data['risks'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
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
              risks.isEmpty ? "PROJECTED IMPACTS" : "KEY RISKS & MITIGATIONS",
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            if (risks.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  "No critical risks identified for this path. Stability is maintained.",
                  style: TextStyle(color: Colors.white30, fontSize: 13),
                ),
              )
            else
              ...risks.map((risk) {
                final type = risk['type'] ?? 'unknown';
                final label = risk['label'] ?? 'MEDIUM';
                final summary = risk['summary'] ?? '';
                final score = (risk['score'] as num?)?.toDouble() ?? 0.5;

                IconData icon = LucideIcons.alertTriangle;
                Color color = Colors.orangeAccent;
                if (type == 'lateness') icon = LucideIcons.clock;
                if (type == 'battery') icon = LucideIcons.battery;
                if (label == 'HIGH') color = AppColors.danger;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  type.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                                Text(
                                  label,
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              summary,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
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

  IconData _getModeIcon(String mode) {
    if (mode.contains("Car")) return LucideIcons.car;
    if (mode.contains("Auto")) return LucideIcons.bus;
    if (mode.contains("Two-Wheeler")) return LucideIcons.bike;
    if (mode.contains("Transit")) return LucideIcons.train;
    if (mode.contains("Walk")) return LucideIcons.footprints;
    return LucideIcons.navigation;
  }
}
