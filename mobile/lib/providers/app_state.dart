import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/risk_state.dart';
import '../models/intervention.dart';
import '../models/snapshot.dart';
import '../models/device_context.dart';
import '../services/context_services.dart';

class AppState extends ChangeNotifier {
  final ContextServices _contextServices = ContextServices();
  DeviceContext _deviceContext = DeviceContext.initial();

  DeviceContext get deviceContext => _deviceContext;
  final RiskState _currentRisk = RiskState(
    score: 84,
    level: RiskLevel.safe,
    timestamp: DateTime.now(),
    reasons: ["Late night motion", "Low battery"],
    history: [72, 75, 80, 82, 84],
  );

  final List<ContextSnapshot> _snapshots = [];
  final List<Intervention> _interventions = [];
  final List<String> _rawMessages = [];
  bool _isLive = true;
  WebSocketChannel? _channel;

  RiskState get currentRisk => _currentRisk;
  List<ContextSnapshot> get snapshots => _snapshots;
  List<Intervention> get interventions => _interventions;
  List<String> get rawMessages => _rawMessages;
  bool get isLive => _isLive;

  AppState() {
    _generateMockData();
    _connectWebSocket();
    _initContextIngestion();
    // Keep internal simulation for fallback or UI stability
    _startSimulatedStream();
  }

  void _initContextIngestion() async {
    debugPrint('[Pulse AppState] Starting context ingestion...');
    // Battery
    _contextServices.batteryStream.listen((info) {
      final oldTrend = _deviceContext.battery.trend;
      final List<int> newTrend = List<int>.from(oldTrend)..add(info.level);
      if (newTrend.length > 20) newTrend.removeAt(0);

      _deviceContext = DeviceContext(
        battery: BatteryInfo(
          level: info.level,
          isCharging: info.isCharging,
          trend: newTrend,
        ),
        location: _deviceContext.location,
        upcomingEvents: _deviceContext.upcomingEvents,
        notifications: _deviceContext.notifications,
        timestamp: DateTime.now(),
      );
      notifyListeners();
      _sendContextSnapshot("battery_change");
    });

    // Location Permission & Stream
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _contextServices.locationStream.listen((info) {
          debugPrint(
            '[Pulse Context] Location Update: ${info.latitude}, ${info.longitude}',
          );
          _deviceContext = DeviceContext(
            battery: _deviceContext.battery,
            location: info,
            upcomingEvents: _deviceContext.upcomingEvents,
            notifications: _deviceContext.notifications,
            timestamp: DateTime.now(),
          );
          notifyListeners();
          _sendContextSnapshot("location_change");
        });
      } else {
        debugPrint('[Pulse Context] Location Permission Denied: $permission');
      }
    } else {
      debugPrint('[Pulse Context] Location Services Disabled');
    }

    // Calendar - Refresh every 15 minutes
    Timer.periodic(const Duration(minutes: 15), (timer) async {
      final events = await _contextServices.getUpcomingEvents();
      debugPrint(
        '[Pulse Context] Calendar Refreshed: ${events.length} events found',
      );
      _deviceContext = DeviceContext(
        battery: _deviceContext.battery,
        location: _deviceContext.location,
        upcomingEvents: events,
        notifications: _deviceContext.notifications,
        timestamp: DateTime.now(),
      );
      notifyListeners();
    });

    // Initial fetch
    final initialEvents = await _contextServices.getUpcomingEvents();
    debugPrint(
      '[Pulse Context] Initial Calendar Fetch: ${initialEvents.length} events found',
    );
    for (var event in initialEvents) {
      debugPrint('  - Event: ${event.title} at ${event.start}');
    }

    _deviceContext = DeviceContext(
      battery: _deviceContext.battery,
      location: _deviceContext.location,
      upcomingEvents: initialEvents,
      notifications: _deviceContext.notifications,
      timestamp: DateTime.now(),
    );
    notifyListeners();

    // Notifications
    await _contextServices.initNotifications((data) {
      debugPrint(
        '[Pulse Context] Notification Received: ${data['packageName']}',
      );
      final newNotif = NotificationInfo(
        packageName: data['packageName'] ?? "unknown",
        title: data['title'] ?? "No Title",
        timestamp: DateTime.now(),
      );
      final newList = [newNotif, ..._deviceContext.notifications];
      if (newList.length > 50) newList.removeLast();

      _deviceContext = DeviceContext(
        battery: _deviceContext.battery,
        location: _deviceContext.location,
        upcomingEvents: _deviceContext.upcomingEvents,
        notifications: newList,
        timestamp: DateTime.now(),
      );
      notifyListeners();
      _sendContextSnapshot("notification_received");
    });
  }

  void _connectWebSocket() {
    try {
      final host = _getBackendHost();
      final wsUrl = 'ws://$host:8080/ws';
      debugPrint('[Pulse WS] Connecting to: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          debugPrint('[Pulse] WS Error: $error');
          _reconnect();
        },
        onDone: () {
          debugPrint('[Pulse] WS Closed');
          _reconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[Pulse] WS Connection failed: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_channel == null || _channel!.closeCode != null) {
        debugPrint('[Pulse] Attempting to reconnect...');
        _connectWebSocket();
      }
    });
  }

  void _handleWebSocketMessage(dynamic message) {
    final String text = message.toString();
    _rawMessages.insert(0, text);
    if (_rawMessages.length > 20) _rawMessages.removeLast();

    try {
      final data = jsonDecode(text);
      debugPrint('[Pulse] Received: ${data['type']}');

      // Here we could update state based on message type
      // e.g., if (data['type'] == 'heartbeat.tick') { ... }
    } catch (e) {
      debugPrint('[Pulse] Error parsing message: $e');
    }

    notifyListeners();
  }

  void _generateMockData() {
    _interventions.add(
      Intervention(
        id: "int_001",
        title: "Charge Device",
        description: "Battery is below 15% and you have a commute coming up.",
        type: "Hardware",
        priority: 1,
        status: InterventionStatus.pending,
        steps: ["Find a charger", "Plug in your phone"],
        impact: "Ensures you stay connected during travel.",
        reason: "Low battery (12%) detected.",
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );
  }

  void _startSimulatedStream() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isLive) return;

      final newSnapshot = ContextSnapshot(
        id: "snap_${DateTime.now().millisecondsSinceEpoch}",
        timestamp: DateTime.now(),
        userId: "user_pulse_01",
        batteryLevel: (90 - timer.tick % 20).toDouble(),
        isCharging: false,
        location: "Office - Room 302",
        activity: "Stationary",
        nextEvent: "Project Review in 20m",
        recentSignals: ["Repeated motion detected", "Phone unlocked 5 times"],
      );

      _snapshots.insert(0, newSnapshot);
      if (_snapshots.length > 50) _snapshots.removeLast();

      notifyListeners();
    });
  }

  void updateInterventionStatus(String id, InterventionStatus status) {
    final index = _interventions.indexWhere((i) => i.id == id);
    if (index != -1) {
      _interventions[index] = _interventions[index].copyWith(status: status);
      notifyListeners();
    }
  }

  void toggleLiveMode() {
    _isLive = !_isLive;
    notifyListeners();
  }

  Future<void> _sendContextSnapshot(String reason) async {
    try {
      final now = DateTime.now();
      final userId = "user1"; // As requested in headers

      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/snapshots');

      // Construct payload matching the requested schema
      final payload = {
        "id": Uuid().v4(),
        "user_id": userId,
        "timestamp": now.toUtc().toIso8601String(),
        "location": {
          "lat": _deviceContext.location.latitude,
          "lon": _deviceContext.location.longitude,
          "accuracy": 5,
          "provider": "gps",
          "source": "gps",
          "place_id": _deviceContext.location.status,
        },
        "calendar": {
          "next_event": _deviceContext.upcomingEvents.isNotEmpty
              ? {
                  "id":
                      "event_${_deviceContext.upcomingEvents.first.title.hashCode}",
                  "title": _deviceContext.upcomingEvents.first.title,
                  "start_time": _deviceContext.upcomingEvents.first.start
                      .toUtc()
                      .toIso8601String(),
                  "end_time": _deviceContext.upcomingEvents.first.end
                      .toUtc()
                      .toIso8601String(),
                  "location_text": "Detected Location",
                  "location": {
                    "lat": _deviceContext.location.latitude,
                    "lon": _deviceContext.location.longitude,
                  },
                  "is_all_day": false,
                  "importance": "high",
                }
              : null,
          "upcoming_events": _deviceContext.upcomingEvents
              .map(
                (e) => {
                  "title": e.title,
                  "start_time": e.start.toUtc().toIso8601String(),
                  "end_time": e.end.toUtc().toIso8601String(),
                },
              )
              .toList(),
        },
        "battery": {
          "level": _deviceContext.battery.level / 100.0,
          "is_charging": _deviceContext.battery.isCharging,
          "power_saver_on": false,
        },
        "notifications": _deviceContext.notifications
            .map(
              (n) => {
                "app_package": n.packageName,
                "title": n.title,
                "posted_at": n.timestamp.toUtc().toIso8601String(),
              },
            )
            .toList(),
        "device_state": {
          "network_type": "wifi",
          "is_roaming": false,
          "screen_on": true,
          "do_not_disturb": false,
          "ringer_mode": "normal",
        },
        "meta": {
          "client_version": "1.0.0",
          "schema_version": "1.0.0",
          "capture_reason": _mapReason(reason),
        },
        "derived": {
          "has_next_event": _deviceContext.upcomingEvents.isNotEmpty,
          "minutes_to_next_event": _deviceContext.upcomingEvents.isNotEmpty
              ? _deviceContext.upcomingEvents.first.start
                    .difference(now)
                    .inMinutes
              : null,
          "is_commute_window": false,
          "battery_band": _deviceContext.battery.level > 20 ? "ok" : "low",
        },
      };

      debugPrint(
        '[Pulse API] Sending context snapshot to $url (Reason: $reason)...',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'X-User-Id': userId},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[Pulse API] Success: Snapshot ingested by backend.');
        debugPrint('[Pulse API] Response: ${response.body}');
      } else {
        debugPrint(
          '[Pulse API] Error: Backend returned ${response.statusCode}',
        );
        debugPrint('[Pulse API] Response: ${response.body}');
      }
    } catch (e) {
      debugPrint('[Pulse API] Exception sending snapshot: $e');
    }
  }

  void triggerManualSnapshot() {
    _sendContextSnapshot("manual_trigger");
  }

  String _mapReason(String reason) {
    switch (reason) {
      case "manual_trigger":
        return "manual";
      case "battery_change":
      case "location_change":
      case "notification_received":
        return "event_change";
      case "timer_tick":
        return "timer";
      default:
        return "event_change";
    }
  }

  String _getBackendHost() {
    String host = 'localhost';
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // For physical devices or emulators on local network
        // Use your computer's local IP address
        host = '192.168.1.4';
      }
    }
    return host;
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}
