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

  final Map<String, List<Map<String, dynamic>>> _traceData = {
    "Commute – Low battery": [
      {"type": "heartbeat.tick", "timestamp": "2026-04-28T08:00:00Z", "data": {"status": "nominal"}},
      {"type": "risk.updated", "timestamp": "2026-04-28T08:05:00Z", "data": {"level": "low", "score": 32.0, "reasons": ["Traffic forming"], "history": [20, 22, 25, 28, 32]}},
      {"type": "risk.updated", "timestamp": "2026-04-28T08:15:00Z", "data": {"level": "high", "score": 78.0, "reasons": ["Battery 15%", "Traffic delay"], "history": [32, 45, 55, 65, 78]}},
      {"type": "intervention.created", "timestamp": "2026-04-28T08:16:00Z", "eventId": "int_001", "data": {"headline": "Switch to cab + Battery Saver", "body": "Traffic is heavy. Switching to a cab now saves 15 min walk."}},
      {"type": "risk.updated", "timestamp": "2026-04-28T08:30:00Z", "data": {"level": "med", "score": 45.0, "reasons": ["In cab", "Charging"], "history": [78, 70, 60, 50, 45]}},
    ],
    "Back-to-back meetings": [
      {"type": "heartbeat.tick", "timestamp": "2026-04-28T13:00:00Z", "data": {"status": "nominal"}},
      {"type": "risk.updated", "timestamp": "2026-04-28T13:10:00Z", "data": {"level": "med", "score": 52.0, "reasons": ["Overload"], "history": [10, 20, 35, 45, 52]}},
    ],
    "Ola Multi-Mode ETA Test": [
      {"type": "heartbeat.tick", "timestamp": "2026-04-28T09:00:00Z", "data": {"status": "nominal"}},
      {"type": "risk.updated", "timestamp": "2026-04-28T09:02:00Z", "data": {"level": "low", "score": 15.0, "reasons": ["Evaluating Transit APIs"], "history": [5, 10, 15]}},
      {"type": "intervention.created", "timestamp": "2026-04-28T09:05:00Z", "eventId": "int_002", "data": {"headline": "Check Alternate Routes", "body": "Verify live traffic data via the Map Pin icon."}},
      {"type": "risk.updated", "timestamp": "2026-04-28T09:10:00Z", "data": {"level": "med", "score": 48.0, "reasons": ["High traffic along route"], "history": [15, 25, 35, 48]}}
    ]
  };

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
              Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    "Scenario Player",
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
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
        items: _traceData.keys.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
        onChanged: (v) => setState(() => _selectedTrace = v!),
      ),
    );
  }

  Widget _buildPlaybackControls(AppState appState) {
    bool isActive = appState.isReplayMode && appState.currentScenarioName == _selectedTrace;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(isActive ? LucideIcons.stopCircle : LucideIcons.play, color: isActive ? Colors.redAccent : Colors.white),
                onPressed: () {
                   if (isActive) {
                     appState.stopReplay();
                   } else {
                     appState.startReplay(_selectedTrace, _traceData[_selectedTrace]!);
                   }
                },
              ),
              Expanded(
                child: Slider(
                  value: appState.isReplayMode ? appState.replayProgress.toDouble() : 0.0,
                  max: 100,
                  onChanged: (v) {
                    if (appState.isReplayMode) appState.seekToProgress(v);
                  },
                  activeColor: AppColors.primary,
                  inactiveColor: Colors.white10,
                ),
              ),
              Text(
                appState.simulatedTime != null ? DateFormat.Hm().format(appState.simulatedTime!) : "--:--",
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
            decoration: BoxDecoration(
              color: appState.currentRisk.levelColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)
            ),
            child: Text(
              appState.currentRisk.levelText.toUpperCase(),
              style: TextStyle(color: appState.currentRisk.levelColor, fontSize: 10, fontWeight: FontWeight.bold)
            ),
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
