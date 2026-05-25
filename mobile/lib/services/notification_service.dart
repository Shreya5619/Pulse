import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Use default mipmap icon
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap if needed
        debugPrint('Notification tapped: ${details.payload}');
      },
    );

    _isInitialized = true;
  }

  Future<void> showDigestNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'pulse_digest_channel',
      'AI Digest',
      channelDescription: 'Notifications for AI generated summaries',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
    );

    final platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      1, // Using ID 1 for digest so it doesn't overwrite the persistent one
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> showPulseNotification({
    required String title,
    required String body,
    required String state,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    // Map state to importance and visibility
    final isCritical = state == 'CRITICAL';
    // ignore: unused_local_variable
    final isAction = state == 'ACTION_NEEDED';

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'pulse_persistent_channel', // id
      'Pulse Status', // title
      channelDescription: 'Persistent notification for Pulse state',
      importance: isCritical ? Importance.high : Importance.low,
      priority: isCritical ? Priority.high : Priority.low,
      ongoing: true, // Make it persistent (cannot be swiped away easily)
      autoCancel: false, // Don't dismiss on tap
      playSound: isCritical,
      enableVibration: isCritical,
      color: _getStateColor(state),
      styleInformation: BigTextStyleInformation(body),
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      0, // Using same ID will update the existing notification
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Color? _getStateColor(String state) {
    switch (state) {
      case 'CRITICAL':
        return const Color(0xFFFF4444);
      case 'ACTION_NEEDED':
        return const Color(0xFF4A9EFF);
      case 'RISK_FORMING':
        return const Color(0xFFFFB830);
      default:
        return const Color(0xFF44FF88); // NOMINAL
    }
  }

  Future<void> requestPermissions() async {
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }
}
