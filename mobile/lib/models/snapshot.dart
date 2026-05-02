class ContextSnapshot {
  final String id;
  final DateTime timestamp;
  final String userId;
  final double batteryLevel;
  final bool isCharging;
  final String location;
  final String activity;
  final String nextEvent;
  final List<String> recentSignals;

  ContextSnapshot({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.batteryLevel,
    required this.isCharging,
    required this.location,
    required this.activity,
    required this.nextEvent,
    required this.recentSignals,
  });

  factory ContextSnapshot.fromJson(Map<String, dynamic> json) {
    return ContextSnapshot(
      id: json['id'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      userId: json['user_id'] ?? '',
      batteryLevel: (json['battery']?['level'] as num? ?? 0.0) * 100.0,
      isCharging: json['battery']?['is_charging'] ?? false,
      location: json['context']?['location_text'] ?? 'Unknown',
      activity: json['context']?['activity'] ?? 'Stationary',
      nextEvent: json['context']?['next_event']?['title'] ?? 'None',
      recentSignals: (json['notification_digest'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}
