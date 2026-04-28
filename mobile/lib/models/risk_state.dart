import 'package:flutter/material.dart';

enum RiskLevel { safe, riskForming, highRisk }

class RiskState {
  final double score;
  final RiskLevel level;
  final DateTime timestamp;
  final List<String> reasons;
  final List<double> history;

  RiskState({
    required this.score,
    required this.level,
    required this.timestamp,
    required this.reasons,
    required this.history,
  });

  String get levelText {
    switch (level) {
      case RiskLevel.safe: return "Safe";
      case RiskLevel.riskForming: return "Risk Forming";
      case RiskLevel.highRisk: return "High Risk";
    }
  }

  Color get levelColor {
    switch (level) {
      case RiskLevel.safe: return Colors.greenAccent;
      case RiskLevel.riskForming: return Colors.orangeAccent;
      case RiskLevel.highRisk: return Colors.redAccent;
    }
  }
}
