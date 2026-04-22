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
}
