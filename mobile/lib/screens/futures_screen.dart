import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';

class FuturesScreen extends StatefulWidget {
  const FuturesScreen({super.key});

  @override
  State<FuturesScreen> createState() => _FuturesScreenState();
}

class _FuturesScreenState extends State<FuturesScreen> {
  int _selectedScenario = 1; // Recommended

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 20),
              _buildSegmentedControl(),
              const SizedBox(height: 24),
              _buildScenarioCard(),
              const SizedBox(height: 32),
              _buildComparativeGraph(),
            ],
          ),
        ),
      ),
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

  Widget _buildScenarioCard() {
    final data = _getScenarioData(_selectedScenario);
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: data.color),
          ),
          const SizedBox(height: 24),
          _metricRow(LucideIcons.clock, "Arrive ${data.eta}", data.color),
          const SizedBox(height: 16),
          _metricRow(LucideIcons.battery, "Battery ${data.battery} at arrival", data.color),
          const SizedBox(height: 16),
          _metricRow(LucideIcons.messageSquare, "New notification debt ${data.notifs}", data.color),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 20),
          Text(
            data.summary,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
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

  Widget _buildComparativeGraph() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("RISK PROJECTION", style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar("Do nothing", 0.85, Colors.redAccent),
            _bar("Recommended", 0.22, Colors.greenAccent),
            _bar("Alternate", 0.45, Colors.orangeAccent),
          ],
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
