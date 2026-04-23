import 'dart:async';
import 'package:flutter/material.dart';
import '../models/risk_state.dart';
import '../models/intervention.dart';
import '../models/snapshot.dart';

class AppState extends ChangeNotifier {
  final RiskState _currentRisk = RiskState(
    score: 84,
    level: RiskLevel.safe,
    timestamp: DateTime.now(),
    reasons: ["Late night motion", "Low battery"],
    history: [72, 75, 80, 82, 84],
  );

  final List<ContextSnapshot> _snapshots = [];
  final List<Intervention> _interventions = [];
  bool _isLive = true;

  RiskState get currentRisk => _currentRisk;
  List<ContextSnapshot> get snapshots => _snapshots;
  List<Intervention> get interventions => _interventions;
  bool get isLive => _isLive;

  AppState() {
    _generateMockData();
    _startSimulatedStream();
  }

  void _generateMockData() {
    _interventions.add(
      Intervention(
        id: "int_001",
        title: "Charge Device",
        description: "Battery is below 15% and you have a commute coming up.",
        type: "Hardware",
        priority: 1,
        status: InterventionStatus.pending,
        steps: ["Find a charger", "Plug in your phone"],
        impact: "Ensures you stay connected during travel.",
        reason: "Low battery (12%) detected.",
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );
  }

  void _startSimulatedStream() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isLive) return;

      final newSnapshot = ContextSnapshot(
        id: "snap_${DateTime.now().millisecondsSinceEpoch}",
        timestamp: DateTime.now(),
        userId: "user_pulse_01",
        batteryLevel: (90 - timer.tick % 20).toDouble(),
        isCharging: false,
        location: "Office - Room 302",
        activity: "Stationary",
        nextEvent: "Project Review in 20m",
        recentSignals: ["Repeated motion detected", "Phone unlocked 5 times"],
      );

      _snapshots.insert(0, newSnapshot);
      if (_snapshots.length > 50) _snapshots.removeLast();

      notifyListeners();
    });
  }

  void updateInterventionStatus(String id, InterventionStatus status) {
    final index = _interventions.indexWhere((i) => i.id == id);
    if (index != -1) {
      _interventions[index] = _interventions[index].copyWith(status: status);
      notifyListeners();
    }
  }

  void toggleLiveMode() {
    _isLive = !_isLive;
    notifyListeners();
  }
}
