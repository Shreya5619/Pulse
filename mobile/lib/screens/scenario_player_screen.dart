import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';

class ScenarioPlayerScreen extends StatefulWidget {
  const ScenarioPlayerScreen({super.key});

  @override
  State<ScenarioPlayerScreen> createState() => _ScenarioPlayerScreenState();
}

class _ScenarioPlayerScreenState extends State<ScenarioPlayerScreen> {
  String _selectedTrace = "Commute – Low battery";

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Scenario Player",
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 24),
              _buildTraceDropdown(),
              const SizedBox(height: 24),
              _buildPlaybackControls(appState),
              const SizedBox(height: 32),
              const Text("DASHBOARD PREVIEW", style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildMiniDashboard(appState),
              const SizedBox(height: 32),
              const Text("SCENARIO KPIs", style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildKPIs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTraceDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: DropdownButton<String>(
        value: _selectedTrace,
        dropdownColor: const Color(0xFF0F1426),
        underline: const SizedBox(),
        isExpanded: true,
        icon: const Icon(LucideIcons.chevronDown, color: Colors.white30),
        items: [
          "Commute – Low battery",
          "Back-to-back meetings",
          "Overload + response debt",
        ].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
        onChanged: (v) => setState(() => _selectedTrace = v!),
      ),
    );
  }

  Widget _buildPlaybackControls(AppState appState) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(appState.isReplayMode ? LucideIcons.pause : LucideIcons.play, color: Colors.white),
                onPressed: () {
                   // Mock trigger for demo
                   if (appState.isReplayMode) appState.stopReplay();
                   else appState.startReplay([]); 
                },
              ),
              Expanded(
                child: Slider(
                  value: appState.replayProgress.toDouble(),
                  max: 100,
                  onChanged: (v) {},
                  activeColor: AppColors.primary,
                  inactiveColor: Colors.white10,
                ),
              ),
              Text(
                appState.simulatedTime != null ? DateFormat.Hm().format(appState.simulatedTime!) : "08:35",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [1.0, 4.0, 10.0].map((s) {
              final isSelected = appState.replaySpeed == s;
              return GestureDetector(
                onTap: () => appState.setReplaySpeed(s),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                  child: Text("${s.toInt()}x", style: TextStyle(color: isSelected ? Colors.white : Colors.white30, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniDashboard(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Current Risk", style: TextStyle(color: Colors.white30, fontSize: 10)),
              Text("${(appState.currentRisk.score).toInt()}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Text("HIGH", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIs() {
    return Column(
      children: [
        _kpiRow("Total late minutes avoided", "18 min", Colors.greenAccent),
        _kpiRow("Notifications suppressed", "42", Colors.blueAccent),
        _kpiRow("Average risk over horizon", "0.34", Colors.orangeAccent),
      ],
    );
  }

  Widget _kpiRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
