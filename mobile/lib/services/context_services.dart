import 'dart:async';
import 'dart:ui';
import 'dart:isolate';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device_context.dart';

@pragma('vm:entry-point')
const String portName = 'PULSE_NOTIF_ISOLATE_PORT';

@pragma('vm:entry-point')
Future<void> onNotificationEvent(NotificationEvent event) async {
  debugPrint(
    '[Pulse Native] Notification caught in background isolate: ${event.packageName}',
  );

  try {
    SendPort? uiPort;
    int attempts = 0;
    // Retry loop to give the main isolate time to register the port during startup/restart
    while (uiPort == null && attempts < 20) {
      uiPort = IsolateNameServer.lookupPortByName(portName);
      if (uiPort == null) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }

    if (uiPort != null) {
      uiPort.send({
        'packageName': event.packageName,
        'title': event.title,
        'text': event.text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('[Pulse Native] Successfully sent to main isolate port');
    } else {
      debugPrint(
        '[Pulse Native] CRITICAL: UI Port NOT FOUND in background isolate after retries.',
      );
    }
  } catch (e) {
    debugPrint('[Pulse Native] Error sending to main isolate: $e');
  }
}

class ContextServices {
  final Battery _battery = Battery();
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();

  // Battery Stream
  Stream<BatteryInfo> get batteryStream {
    return _battery.onBatteryStateChanged.asyncMap((state) async {
      final level = await _battery.batteryLevel;
      return BatteryInfo(
        level: level,
        isCharging: state == BatteryState.charging,
      );
    });
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
      var status = await Permission.calendar.status;
      if (!status.isGranted) {
        status = await Permission.calendar.request();
      }

      if (status.isGranted) {
        final calendars = await _calendarPlugin.retrieveCalendars();
        if (calendars.isSuccess &&
            calendars.data != null &&
            calendars.data!.isNotEmpty) {
          var selectedCalendar = calendars.data!.firstWhere(
            (c) => c.isDefault ?? false,
            orElse: () => calendars.data!.firstWhere(
              (c) => c.name?.toLowerCase().contains('google') ?? false,
              orElse: () => calendars.data!.first,
            ),
          );

          final calendarId = selectedCalendar.id;
          final now = DateTime.now();
          final end = now.add(const Duration(days: 1));

          final events = await _calendarPlugin.retrieveEvents(
            calendarId,
            RetrieveEventsParams(startDate: now, endDate: end),
          );

          if (events.isSuccess && events.data != null && events.data!.isNotEmpty) {
            return events.data!
                .map(
                  (e) => CalendarEvent(
                    title: e.title ?? "Untitled",
                    start: e.start ?? now,
                    end: e.end ?? now,
                    locationText: e.location,
                  ),
                )
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint("Calendar Error: $e");
    }

    // Return empty list if no events found
    return [];
  }

  // Notifications
  Future<void> initNotifications(Function(Map<String, dynamic>) onEvent) async {
    try {
      bool hasPermission = await NotificationsListener.hasPermission ?? false;
      if (!hasPermission) {
        await NotificationsListener.openPermissionSettings();
        return;
      }

      // Register the port so the background isolate can find it
      IsolateNameServer.removePortNameMapping(portName);
      final ReceivePort uiReceivePort = ReceivePort();
      IsolateNameServer.registerPortWithName(uiReceivePort.sendPort, portName);

      uiReceivePort.listen((data) {
        debugPrint(
          '[Pulse Context] Success! Data received from background isolate: ${data['packageName']}',
        );
        onEvent(data as Map<String, dynamic>);
      });

      debugPrint('[Pulse Context] Initializing Notification Listener...');
      await NotificationsListener.initialize(
        callbackHandle: onNotificationEvent,
      );

      debugPrint(
        '[Pulse Context] Notification Listener Initialized Successfully',
      );
    } catch (e) {
      debugPrint('[Pulse Context] Notification Init Error: $e');
    }
  }
}

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
