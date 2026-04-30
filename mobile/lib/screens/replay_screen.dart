import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';

class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  String? _selectedScenario;

  final Map<String, List<Map<String, dynamic>>> _scenarios = {
    "Morning Commute Stress": [
      {
        "type": "heartbeat.tick",
        "timestamp": "2026-04-28T08:00:00Z",
        "data": {"status": "nominal", "score": 0.1},
      },
      {
        "type": "risk.updated",
        "timestamp": "2026-04-28T08:05:00Z",
        "data": {
          "level": "low",
          "score": 0.3,
          "reason": "Traffic detected on route",
        },
      },
      {
        "type": "risk.updated",
        "timestamp": "2026-04-28T08:15:00Z",
        "data": {
          "level": "high",
          "score": 0.7,
          "reason": "Severe delay + Low Battery",
        },
      },
      {
        "type": "intervention.created",
        "timestamp": "2026-04-28T08:16:00Z",
        "eventId": "int_replay_001",
        "data": {
          "headline": "Switch to Battery Saver",
          "body":
              "Traffic delay is now 20 mins. Switch to power saving mode to ensure you reach the meeting with charge.",
        },
      },
      {
        "type": "heartbeat.tick",
        "timestamp": "2026-04-28T08:20:00Z",
        "data": {"status": "action_taken", "score": 0.4},
      },
    ],
    "Back-to-Back Meetings": [
      {
        "type": "heartbeat.tick",
        "timestamp": "2026-04-28T13:00:00Z",
        "data": {"status": "nominal"},
      },
      {
        "type": "intervention.created",
        "timestamp": "2026-04-28T13:05:00Z",
        "eventId": "int_replay_002",
        "data": {
          "headline": "Coffee Break Suggested",
          "body":
              "You have a 10m gap between meetings. Pulse suggests a quick break to avoid burnout.",
        },
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          "Replay Simulator",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Scenario",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ..._scenarios.keys
                .map((name) => _buildScenarioCard(name, appState))
                .toList(),

            const Spacer(),

            if (appState.isReplayMode) _buildPlaybackControls(appState),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioCard(String name, AppState appState) {
    bool isSelected = _selectedScenario == name;
    return GestureDetector(
      onTap: () => setState(() => _selectedScenario = name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? LucideIcons.playCircle : LucideIcons.circle,
              color: isSelected ? Colors.blueAccent : Colors.white30,
            ),
            const SizedBox(width: 16),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected && !appState.isReplayMode)
              TextButton(
                onPressed: () {
                  appState.startReplay(name, _scenarios[name]!);
                },
                child: const Text("START"),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackControls(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SIMULATED TIME",
                    style: TextStyle(color: Colors.white30, fontSize: 10),
                  ),
                  Text(
                    DateFormat.Hms().format(
                      appState.simulatedTime ?? DateTime.now(),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _speedButton(appState, 1.0),
                  _speedButton(appState, 5.0),
                  _speedButton(appState, 10.0),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: appState.replayProgress / 100,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => appState.stopReplay(),
            icon: const Icon(LucideIcons.stopCircle),
            label: const Text("STOP SIMULATION"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.redAccent,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedButton(AppState appState, double speed) {
    bool isSelected = appState.replaySpeed == speed;
    return GestureDetector(
      onTap: () => appState.setReplaySpeed(speed),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          "${speed.toInt()}x",
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white30,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
