
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
    final now = DateTime.now();
    return DeviceContext(
      battery: BatteryInfo(level: 85, isCharging: false),
      location: LocationInfo(latitude: 37.7749, longitude: -122.4194, status: "Home"),
      upcomingEvents: [],
      notifications: [],
      timestamp: now,
    );
  }
}

class BatteryInfo {
  final int level;
  final bool isCharging;
  final bool isInBatterySaveMode;
  final List<int> trend; // Last 10 readings

  BatteryInfo({
    required this.level,
    required this.isCharging,
    this.isInBatterySaveMode = false,
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
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? startLocation;

  CalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    this.locationText,
    this.latitude,
    this.longitude,
    this.startLocation,
  });
}

class NotificationInfo {
  final String packageName;
  final String appName;
  final String title;
  final String text;
  final String category; // e.g., URGENT_OTP, IMPORTANT_SENDER, etc.
  final DateTime timestamp;

  NotificationInfo({
    required this.packageName,
    required this.appName,
    required this.title,
    required this.text,
    this.category = "IGNORABLE",
    required this.timestamp,
  });

  factory NotificationInfo.fromMap(Map<String, dynamic> map) {
    return NotificationInfo(
      packageName: map['packageName'] ?? 'unknown',
      appName: map['appName'] ?? map['packageName'] ?? 'Unknown App',
      title: map['title'] ?? 'No Title',
      text: map['text'] ?? '',
      category: map['category'] ?? 'IGNORABLE',
      timestamp: map['time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['time'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'appName': appName,
      'title': title,
      'text': text,
      'category': category,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
