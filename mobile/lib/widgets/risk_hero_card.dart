import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'glass_card.dart';
import '../screens/graph_explanation_screen.dart';

class RiskHeroCard extends StatelessWidget {
  const RiskHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final count = state.risksNext90Min;
        debugPrint('[Pulse UI] RiskHeroCard count: $count, types: ${state.activeRiskTypes}');
        final riskTypes = state.activeRiskTypes;
        
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

        final summaryLine = riskTypes.isEmpty
            ? "Everything looks nominal for now."
            : riskTypes.map((t) => typeMap[t] ?? t).join(" + ");

        final title = "$count ${count == 1 ? 'risk' : 'risks'} forming in next 90 minutes";

        return GestureDetector(
          onTap: () {
            final risks = state.currentRiskSnapshot?.risks ?? [];
            if (risks.isNotEmpty) {
              final topRisk = risks[0];
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (Widget child, Animation<double> animation) {
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
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  timeRange,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Wrap(
                    key: ValueKey(riskTypes.join(',')),
                    spacing: 8,
                    runSpacing: 8,
                    children: riskTypes.isEmpty
                        ? [_statusChip("Nominal", Colors.greenAccent)]
                        : riskTypes.map((t) => _statusChip(typeMap[t] ?? t, _getColorForType(t))).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(LucideIcons.activity, size: 12, color: Colors.white30),
                    const SizedBox(width: 6),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          summaryLine,
                          key: ValueKey(summaryLine),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.4),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
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
