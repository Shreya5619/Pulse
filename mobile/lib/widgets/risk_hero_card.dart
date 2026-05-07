import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'glass_card.dart';
import '../screens/graph_explanation_screen.dart';
import '../models/risk_snapshot.dart';

class RiskHeroCard extends StatelessWidget {
  const RiskHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final risks = state.currentRiskSnapshot?.risks ?? [];

        // Filter high risks (score >= 0.4) for count and main tags
        final highRisks = risks.where((r) => (r.score) >= 0.4).toList();
        final count = highRisks.length;

        debugPrint(
          '[Pulse UI] RiskHeroCard high-risk count: $count / total: ${risks.length}',
        );

        final highRiskTypes = highRisks
            .map((r) => r.type.toString().split('.').last)
            .toSet()
            .toList();

        final now = DateTime.now();
        final windowEnd = now.add(const Duration(minutes: 90));
        final timeFormatter = DateFormat('HH:mm');
        final timeRange = "Now → ${timeFormatter.format(windowEnd)}";

        // Map internal types to user-friendly labels
        final typeMap = {
          'lateness': 'Lateness',
          'battery': 'Low Battery',
          'overload': 'Overload',
          'response_debt': 'Response Debt',
        };

        // ignore: unused_local_variable
        final summaryLine = highRiskTypes.isEmpty
            ? "Everything looks nominal for now."
            : highRiskTypes.map((t) => typeMap[t] ?? t).join(" + ");

        final title =
            "$count ${count == 1 ? 'risk' : 'risks'}  forming in next 90 minutes";

        return GestureDetector(
          onTap: () {
            if (highRisks.isNotEmpty) {
              final topRisk = highRisks[0];
              if (topRisk.nodeId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GraphExplanationScreen(
                      nodeId: topRisk.nodeId!,
                      riskType: topRisk.type.name,
                    ),
                  ),
                );
              }
            }
          },
          child: GlassCard(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.0, 0.2),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                        child: Text(
                          title,
                          key: ValueKey(count),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  timeRange,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                // Main chips: only high risks (>=0.4)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Wrap(
                    key: ValueKey(highRiskTypes.join(',')),
                    spacing: 8,
                    runSpacing: 8,
                    children: highRiskTypes.isEmpty
                        ? [_statusChip("Nominal", Colors.greenAccent)]
                        : highRiskTypes
                              .map(
                                (t) => _statusChip(
                                  typeMap[t] ?? t,
                                  _getColorForType(t),
                                ),
                              )
                              .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                // All risks boxes with scores
                if (risks.isNotEmpty) ...[
                  Text(
                    "All risks (${risks.length}):",
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: risks
                        .map((risk) => _riskBox(risk, typeMap))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

  Widget _riskBox(RiskScore risk, Map<String, String> typeMap) {
    final typeName = risk.type.toString().split('.').last;
    final typeLabel = typeMap[typeName] ?? typeName;
    final score = risk.score.toStringAsFixed(2);
    final isHigh = risk.score >= 0.4;
    final color = isHigh ? _getColorForType(typeName) : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            typeLabel,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: isHigh
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              score,
              style: TextStyle(
                color: isHigh ? Colors.white : Colors.white54,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'lateness':
        return Colors.redAccent;
      case 'battery':
        return Colors.orangeAccent;
      case 'overload':
        return Colors.purpleAccent;
      case 'response_debt':
        return Colors.blueAccent;
      default:
        return Colors.white54;
    }
  }
}
