import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import '../models/device_context.dart';

class ContextServices {
  final Battery _battery = Battery();
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();
  
  // Battery Stream
  Stream<BatteryInfo> get batteryStream {
    return StreamGroup.merge([
      _battery.onBatteryStateChanged.asyncMap((state) async {
        final level = await _battery.batteryLevel;
        return BatteryInfo(level: level, isCharging: state == BatteryState.charging);
      }),
      Stream.periodic(const Duration(minutes: 1)).asyncMap((_) async {
        final level = await _battery.batteryLevel;
        final state = await _battery.onBatteryStateChanged.first; // Simplified
        return BatteryInfo(level: level, isCharging: state == BatteryState.charging);
      })
    ]);
  }

  // Location Stream
  Stream<LocationInfo> get locationStream {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 100,
      ),
    ).map((position) => LocationInfo(
      latitude: position.latitude,
      longitude: position.longitude,
      status: "Active",
    )).handleError((error) {
      return LocationInfo(latitude: 0, longitude: 0, status: "Error: $error");
    });
  }

  // Calendar
  Future<List<CalendarEvent>> getUpcomingEvents() async {
    try {
      var permissions = await _calendarPlugin.hasPermissions();
      if (permissions.isSuccess && !permissions.data!) {
        permissions = await _calendarPlugin.requestPermissions();
      }

      if (permissions.isSuccess && permissions.data!) {
        final calendars = await _calendarPlugin.retrieveCalendars();
        if (calendars.isSuccess && calendars.data!.isNotEmpty) {
          final calendarId = calendars.data!.first.id;
          final now = DateTime.now();
          final end = now.add(const Duration(days: 1));
          
          final events = await _calendarPlugin.retrieveEvents(
            calendarId,
            RetrieveEventsParams(startDate: now, endDate: end),
          );

          if (events.isSuccess && events.data != null) {
            return events.data!.map((e) => CalendarEvent(
              title: e.title ?? "Untitled",
              start: e.start ?? now,
              end: e.end ?? now,
            )).toList();
          }
        }
      }
    } catch (e) {
      print("Calendar Error: $e");
    }
    return [];
  }

  // Notifications
  static void onNotificationEvent(NotificationEvent event) {
    // This is a static method required by the plugin
    print("Notification: ${event.packageName}");
  }

  Future<void> initNotifications(Function(NotificationEvent) onEvent) async {
    bool hasPermission = await NotificationsListener.hasPermission ?? false;
    if (!hasPermission) {
      await NotificationsListener.openPermissionSettings();
    }
    
    await NotificationsListener.initialize(callbackHandle: onNotificationEvent);
    NotificationsListener.receivePort?.listen((event) {
      onEvent(event as NotificationEvent);
    });
  }
}

// Helper for merging streams since I don't want to add async package just for this
class StreamGroup {
  static Stream<T> merge<T>(Iterable<Stream<T>> streams) {
    final controller = StreamController<T>();
    int activeStreams = 0;
    
    for (final stream in streams) {
      activeStreams++;
      stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {
          activeStreams--;
          if (activeStreams == 0) controller.close();
        },
      );
    }
    return controller.stream;
  }
}
