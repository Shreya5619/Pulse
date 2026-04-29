import 'package:flutter/material.dart';

enum RiskType { lateness, battery, responseDebt, overload }

enum RiskLabel { low, medium, high }

class RiskScore {
  final RiskType type;
  final double score;
  final RiskLabel label;
  final String? nodeId;
  final String summary;
  final List<String> causes;

  RiskScore({
    required this.type,
    required this.score,
    required this.label,
    this.nodeId,
    required this.summary,
    required this.causes,
  });

  factory RiskScore.fromJson(Map<String, dynamic> json) {
    return RiskScore(
      type: _parseType(json['type']),
      score: (json['score'] as num).toDouble(),
      label: _parseLabel(json['label']),
      nodeId: json['nodeId'],
      summary: json['summary'] ?? '',
      causes: List<String>.from(json['causes'] ?? []),
    );
  }

  static RiskType _parseType(String? type) {
    switch (type) {
      case 'lateness': return RiskType.lateness;
      case 'battery': return RiskType.battery;
      case 'response_debt': return RiskType.responseDebt;
      case 'overload': return RiskType.overload;
      default: return RiskType.lateness;
    }
  }

  static RiskLabel _parseLabel(String? label) {
    switch (label) {
      case 'HIGH': return RiskLabel.high;
      case 'MEDIUM': return RiskLabel.medium;
      case 'LOW': return RiskLabel.low;
      default: return RiskLabel.low;
    }
  }

  Color get color {
    switch (label) {
      case RiskLabel.high: return Colors.redAccent;
      case RiskLabel.medium: return Colors.orangeAccent;
      case RiskLabel.low: return Colors.greenAccent;
    }
  }
}

class RiskSnapshot {
  final String userId;
  final DateTime timestamp;
  final List<RiskScore> risks;

  RiskSnapshot({
    required this.userId,
    required this.timestamp,
    required this.risks,
  });

  factory RiskSnapshot.fromJson(Map<String, dynamic> json) {
    return RiskSnapshot(
      userId: json['userId'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      risks: (json['risks'] as List<dynamic>?)
          ?.map((r) => RiskScore.fromJson(r))
          .toList() ?? [],
    );
  }
}
