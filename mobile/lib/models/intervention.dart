enum InterventionStatus { pending, accepted, dismissed, done, snoozed }

class Intervention {
  final String id;
  final String title;
  final String description;
  final String type;
  final int priority;
  final InterventionStatus status;
  final List<String> steps;
  final String impact;
  final String reason;
  final DateTime createdAt;

  Intervention({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.status,
    required this.steps,
    required this.impact,
    required this.reason,
    required this.createdAt,
  });

  Intervention copyWith({InterventionStatus? status}) {
    return Intervention(
      id: id,
      title: title,
      description: description,
      type: type,
      priority: priority,
      status: status ?? this.status,
      steps: steps,
      impact: impact,
      reason: reason,
      createdAt: createdAt,
    );
  }
}
