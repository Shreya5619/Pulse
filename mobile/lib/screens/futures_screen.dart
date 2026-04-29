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
  int _selectedScenario = 1; // Recommended

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final futures = state.currentFutures?['futures'] as List<dynamic>? ?? [];
        
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Next 2 hours",
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const RouteEtaStrip(isMini: true),
                  const SizedBox(height: 20),
                  _buildSegmentedControl(),
                  const SizedBox(height: 24),
                  if (futures.isNotEmpty)
                    _buildScenarioCard(futures[_selectedScenario.clamp(0, futures.length - 1)])
                  else
                    const Center(child: Text("No projections available", style: TextStyle(color: Colors.white30))),
                  const SizedBox(height: 32),
                  if (futures.isNotEmpty)
                    _buildComparativeGraph(futures),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _segment(0, "Do nothing"),
          _segment(1, "Recommended"),
          _segment(2, "Alternate"),
        ],
      ),
    );
  }

  Widget _segment(int index, String label) {
    final isSelected = _selectedScenario == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedScenario = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.primary.withOpacity(0.5) : Colors.transparent),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: isSelected ? Colors.white : Colors.white30, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioCard(dynamic data) {
    final metrics = data['metrics'];
    final risks = data['risks'] as List<dynamic>? ?? [];
    final stressScore = (metrics['stressScore'] as num?)?.toDouble() ?? 0.0;
    final color = stressScore > 0.7 ? Colors.redAccent : stressScore > 0.4 ? Colors.orangeAccent : Colors.greenAccent;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data['title'] ?? "Scenario",
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              _riskIconCount(risks.length),
            ],
          ),
          const SizedBox(height: 24),
          _metricRow(LucideIcons.clock, _formatScenarioEta(data, metrics), color),
          const SizedBox(height: 16),
          _metricRow(LucideIcons.battery, "Battery: ${metrics['batteryPercent'] ?? '?'}% at end", color),
          const SizedBox(height: 16),
          _metricRow(LucideIcons.alertCircle, metrics['expectedLatenessMinutes'] > 0 
            ? "Expected late: ${metrics['expectedLatenessMinutes']} min" 
            : "On time arrival", color),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 20),
          Text(
            data['description'] ?? "",
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _riskIconCount(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.activity, size: 12, color: count > 0 ? Colors.redAccent : Colors.greenAccent),
          const SizedBox(width: 4),
          Text(
            "$count risks",
            style: TextStyle(
              color: count > 0 ? Colors.redAccent : Colors.greenAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }

  Widget _buildComparativeGraph(List<dynamic> futures) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("RISK PROJECTION", style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: futures.map((f) {
            final stress = (f['metrics']['stressScore'] as num?)?.toDouble() ?? 0.0;
            final color = stress > 0.7 ? Colors.redAccent : stress > 0.4 ? Colors.orangeAccent : Colors.greenAccent;
            return _bar(f['title'] ?? "Scenario", stress, color);
          }).toList(),
        ),
      ],
    );
  }

  Widget _bar(String label, double score, Color color) {
    return Column(
      children: [
        Text("${(score * 100).toInt()}", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 100 * score,
          decoration: BoxDecoration(color: color.withOpacity(0.3), borderRadius: const BorderRadius.vertical(top: Radius.circular(4)), border: Border.all(color: color.withOpacity(0.5))),
        ),
        const SizedBox(height: 8),
        Text(label.split(" ")[0], style: const TextStyle(color: Colors.white24, fontSize: 8)),
      ],
    );
  }

  String _formatScenarioEta(dynamic data, dynamic metrics) {
    final etaMinutes = metrics['etaMinutes'] ?? 0;
    final lateness = metrics['expectedLatenessMinutes'] ?? 0;
    final status = lateness > 0 ? "(late)" : "(on time)";
    
    // For demo, we can derive a "leave at" time based on the scenario type
    String leaveAt = "09:40";
    if (data['id'] == "DO_NOTHING") leaveAt = "09:55";
    if (data['id'] == "ALTERNATE") leaveAt = "10:10";

    return "Leave at $leaveAt · ETA ${etaMinutes} min $status";
  }

  _ScenarioData _getScenarioData(int index) {
    switch (index) {
      case 0:
        return _ScenarioData(
          "Do nothing",
          "12–18 min late",
          "6%",
          "+24",
          "High chance you’ll both be late and unreachable mid-meeting.",
          Colors.redAccent,
        );
      case 1:
        return _ScenarioData(
          "Recommended plan",
          "on time (9:57)",
          "14%",
          "+4",
          "Optimal balance. Switching to cab now saves 15 mins of walking in traffic.",
          Colors.greenAccent,
        );
      case 2:
        return _ScenarioData(
          "Alternate path",
          "5 min late",
          "18%",
          "+12",
          "Safest for battery, but involves a longer walk and slight delay.",
          Colors.orangeAccent,
        );
      default:
        return _getScenarioData(1);
    }
  }
}

class _ScenarioData {
  final String title;
  final String eta;
  final String battery;
  final String notifs;
  final String summary;
  final Color color;

  _ScenarioData(this.title, this.eta, this.battery, this.notifs, this.summary, this.color);
}
