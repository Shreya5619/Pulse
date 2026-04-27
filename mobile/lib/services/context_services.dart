import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device_context.dart';

class ContextServices {
  final Battery _battery = Battery();
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();

  // Battery Stream
  Stream<BatteryInfo> get batteryStream {
    return StreamGroup.merge([
      _battery.onBatteryStateChanged.asyncMap((state) async {
        final level = await _battery.batteryLevel;
        return BatteryInfo(
          level: level,
          isCharging: state == BatteryState.charging,
        );
      }),
      Stream.periodic(const Duration(minutes: 1)).asyncMap((_) async {
        final level = await _battery.batteryLevel;
        final state = await _battery.onBatteryStateChanged.first; // Simplified
        return BatteryInfo(
          level: level,
          isCharging: state == BatteryState.charging,
        );
      }),
    ]);
  }

  // Location Stream
  Stream<LocationInfo> get locationStream {
    return Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            distanceFilter: 100,
          ),
        )
        .map(
          (position) => LocationInfo(
            latitude: position.latitude,
            longitude: position.longitude,
            status: "Active",
          ),
        )
        .handleError((error) {
          return LocationInfo(
            latitude: 0,
            longitude: 0,
            status: "Error: $error",
          );
        });
  }

  // Calendar
  Future<List<CalendarEvent>> getUpcomingEvents() async {
    try {
      // Explicitly request using permission_handler for better reliability
      var status = await Permission.calendar.status;
      if (!status.isGranted) {
        status = await Permission.calendar.request();
      }

      if (status.isGranted) {
        final calendars = await _calendarPlugin.retrieveCalendars();
        if (calendars.isSuccess && calendars.data != null && calendars.data!.isNotEmpty) {
          // Debug: Print all available calendars
          for (var cal in calendars.data!) {
            debugPrint('[Pulse Calendar] Found Calendar: ${cal.name} (ID: ${cal.id}, IsDefault: ${cal.isDefault})');
          }

          // Prefer primary/default calendar, then fall back to any calendar with "google" in name, then just the first one
          var selectedCalendar = calendars.data!.firstWhere(
            (c) => c.isDefault ?? false,
            orElse: () => calendars.data!.firstWhere(
              (c) => c.name?.toLowerCase().contains('google') ?? false,
              orElse: () => calendars.data!.first,
            ),
          );

          debugPrint('[Pulse Calendar] Selected: ${selectedCalendar.name}');
          
          final calendarId = selectedCalendar.id;
          final now = DateTime.now();
          final end = now.add(const Duration(days: 1));

          final events = await _calendarPlugin.retrieveEvents(
            calendarId,
            RetrieveEventsParams(startDate: now, endDate: end),
          );

          if (events.isSuccess && events.data != null) {
            return events.data!
                .map(
                  (e) => CalendarEvent(
                    title: e.title ?? "Untitled",
                    start: e.start ?? now,
                    end: e.end ?? now,
                  ),
                )
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint("Calendar Error: $e");
    }
    return [];
  }

  // Notifications
  static void onNotificationEvent(NotificationEvent event) {
    // This is a static method required by the plugin
    debugPrint("Notification: ${event.packageName}");
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
