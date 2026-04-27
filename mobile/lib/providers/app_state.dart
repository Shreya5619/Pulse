import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
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
    // Battery
    _contextServices.batteryStream.listen((info) {
      final oldTrend = _deviceContext.battery.trend;
      final newTrend = [...oldTrend, info.level];
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
    });

    // Location Permission & Stream
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (serviceEnabled) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        _contextServices.locationStream.listen((info) {
          debugPrint('[Pulse Context] Location Update: ${info.latitude}, ${info.longitude}');
          _deviceContext = DeviceContext(
            battery: _deviceContext.battery,
            location: info,
            upcomingEvents: _deviceContext.upcomingEvents,
            notifications: _deviceContext.notifications,
            timestamp: DateTime.now(),
          );
          notifyListeners();
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
      debugPrint('[Pulse Context] Calendar Refreshed: ${events.length} events found');
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
    debugPrint('[Pulse Context] Initial Calendar Fetch: ${initialEvents.length} events found');
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
    await _contextServices.initNotifications((event) {
      debugPrint('[Pulse Context] Notification Received: ${event.packageName}');
      final newNotif = NotificationInfo(
        packageName: event.packageName ?? "unknown",
        title: event.title,
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
    });
  }

  void _connectWebSocket() {
    try {
      // DEFAULT: Use 10.0.2.2 for Android Emulators, localhost for everything else
      String host = 'localhost';
      if (!kIsWeb) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          host = '10.0.2.2';
        }
      }

      // OPTIONAL: If testing on a PHYSICAL device, use your machine's IP:
      host = '192.168.0.101';
      final wsUrl = 'ws://$host:8080/ws';
      debugPrint('[Pulse] Attempting connection to: $wsUrl');

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

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}
