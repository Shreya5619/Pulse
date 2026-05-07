// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui';
import 'dart:isolate';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:usage_stats/usage_stats.dart';
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
    while (uiPort == null && attempts < 50) {
      uiPort = IsolateNameServer.lookupPortByName(portName);
      if (uiPort == null) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }

    debugPrint(
      '[Pulse Native] Port lookup finished after $attempts attempts. Found: ${uiPort != null}',
    );

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
        '[Pulse Native] CRITICAL: UI Port NOT FOUND in background isolate after 50 retries (5s). Check if IsolateNameServer registration is working.',
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
    // Combine state change stream with a periodic timer to detect battery saver mode toggles
    return StreamGroup.merge([
          _battery.onBatteryStateChanged,
          Stream.periodic(const Duration(seconds: 2)),
        ])
        .asyncMap((_) async {
          final level = await _battery.batteryLevel;
          bool isSaveMode = false;
          try {
            isSaveMode = await _battery.isInBatterySaveMode;
          } catch (_) {
            // Handle unimplemented platforms
          }
          final state = await _battery.batteryState;
          return BatteryInfo(
            level: level,
            isCharging: state == BatteryState.charging,
            isInBatterySaveMode: isSaveMode,
          );
        })
        .distinct(
          (prev, curr) =>
              prev.level == curr.level &&
              prev.isCharging == curr.isCharging &&
              prev.isInBatterySaveMode == curr.isInBatterySaveMode,
        );
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

          if (events.isSuccess &&
              events.data != null &&
              events.data!.isNotEmpty) {
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

  // App Usage
  Future<List<Map<String, dynamic>>> getAppUsage(
    DateTime start,
    DateTime end,
  ) async {
    try {
      bool? isPermissionGranted = await UsageStats.checkUsagePermission();
      if (isPermissionGranted == false) {
        await UsageStats.grantUsagePermission();
        // Wait a bit for user to potentially grant permission and come back
        await Future.delayed(const Duration(seconds: 2));
        isPermissionGranted = await UsageStats.checkUsagePermission();
      }

      if (isPermissionGranted == true) {
        List<EventUsageInfo> events = await UsageStats.queryEvents(start, end);
        // Sort events by timestamp
        events.sort((a, b) => a.timeStamp!.compareTo(b.timeStamp!));

        List<Map<String, dynamic>> usageData = [];
        Map<String, int?> lastStartTimes = {};

        for (var event in events) {
          // 1: MOVE_TO_FOREGROUND, 2: MOVE_TO_BACKGROUND
          if (event.eventType == '1') {
            lastStartTimes[event.packageName!] = int.tryParse(event.timeStamp!);
          } else if (event.eventType == '2') {
            if (lastStartTimes.containsKey(event.packageName)) {
              int startTime = lastStartTimes[event.packageName]!;
              int endTime = int.tryParse(event.timeStamp!) ?? startTime;

              if (endTime > startTime) {
                usageData.add({
                  'packageName': event.packageName,
                  'startTime': startTime,
                  'endTime': endTime,
                });
              }
              lastStartTimes.remove(event.packageName);
            }
          }
        }
        return usageData;
      }
    } catch (e) {
      debugPrint("Usage Stats Error: $e");
    }
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
      bool registered = IsolateNameServer.registerPortWithName(
        uiReceivePort.sendPort,
        portName,
      );
      debugPrint('[Pulse Context] Port registration status: $registered');

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
