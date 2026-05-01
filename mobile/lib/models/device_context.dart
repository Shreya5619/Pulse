
class DeviceContext {
  final BatteryInfo battery;
  final LocationInfo location;
  final List<CalendarEvent> upcomingEvents;
  final List<NotificationInfo> notifications;
  final DateTime timestamp;

  DeviceContext({
    required this.battery,
    required this.location,
    required this.upcomingEvents,
    required this.notifications,
    required this.timestamp,
  });

  factory DeviceContext.initial() {
    return DeviceContext(
      battery: BatteryInfo(level: 0, isCharging: false),
      location: LocationInfo(latitude: 0, longitude: 0, status: "Unknown"),
      upcomingEvents: [],
      notifications: [],
      timestamp: DateTime.now(),
    );
  }
}

class BatteryInfo {
  final int level;
  final bool isCharging;
  final List<int> trend; // Last 10 readings

  BatteryInfo({
    required this.level,
    required this.isCharging,
    this.trend = const [],
  });
}

class LocationInfo {
  final double latitude;
  final double longitude;
  final String status;

  LocationInfo({
    required this.latitude,
    required this.longitude,
    required this.status,
  });
}

class CalendarEvent {
  final String title;
  final DateTime start;
  final DateTime end;

  CalendarEvent({
    required this.title,
    required this.start,
    required this.end,
  });
}

class NotificationInfo {
  final String packageName;
  final String? title;
  final String? text;
  final String category; // e.g., URGENT_OTP, IMPORTANT_SENDER, etc.
  final DateTime timestamp;

  NotificationInfo({
    required this.packageName,
    this.title,
    this.text,
    this.category = "IGNORABLE",
    required this.timestamp,
  });
}
