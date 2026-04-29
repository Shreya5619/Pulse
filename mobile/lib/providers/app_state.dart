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
import '../services/local_repository.dart';
import '../models/risk_snapshot.dart';

class TimelineEvent {
  final String id;
  final DateTime timestamp;
  final String type;
  final String agent;
  final String text;
  final Map<String, dynamic>? data;

  TimelineEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.agent,
    required this.text,
    this.data,
  });
}

class AppointmentEtaInfo {
  final bool hasRoute;
  final String? reason;
  final int? durationSeconds;
  final int? distanceMeters;
  final String? travelMode;
  final Map<String, dynamic>? worstSegment;
  final String? eventId;
  final String? eventTitle;
  final String? eventTime;
  final String? destinationName;
  final int? leaveInMinutes;
  final String? latenessRisk;
  final String? etaDisplay;

  AppointmentEtaInfo({
    required this.hasRoute,
    this.reason,
    this.durationSeconds,
    this.distanceMeters,
    this.travelMode,
    this.worstSegment,
    this.eventId,
    this.eventTitle,
    this.eventTime,
    this.destinationName,
    this.leaveInMinutes,
    this.latenessRisk,
    this.etaDisplay,
  });

  factory AppointmentEtaInfo.fromJson(Map<String, dynamic> json) {
    return AppointmentEtaInfo(
      hasRoute: json['hasRoute'] ?? false,
      reason: json['reason'],
      durationSeconds: json['durationSeconds'],
      distanceMeters: json['distanceMeters'],
      travelMode: json['travelMode'],
      worstSegment: json['worstSegment'],
      eventId: json['eventId'],
      eventTitle: json['eventTitle'],
      eventTime: json['eventTime'],
      destinationName: json['destinationName'],
      leaveInMinutes: json['leaveInMinutes'],
      latenessRisk: json['latenessRisk'],
      etaDisplay: json['etaDisplay'],
    );
  }

  factory AppointmentEtaInfo.empty() => AppointmentEtaInfo(hasRoute: false);
}

class AppState extends ChangeNotifier {
  final ContextServices _contextServices = ContextServices();
  final LocalRepository _localRepo = LocalRepository();
  DeviceContext _deviceContext = DeviceContext.initial();
  String _userId = "user1";

  DeviceContext get deviceContext => _deviceContext;
  RiskState _currentRisk = RiskState(
    score: 0,
    level: RiskLevel.safe,
    timestamp: DateTime.now(),
    reasons: [],
    history: [],
  );

  final List<ContextSnapshot> _snapshots = [];
  List<Intervention> _interventions = [];
  List<TimelineEvent> _timelineEvents = [];
  final List<String> _rawMessages = [];
  bool _isLive = true;
  WebSocketChannel? _channel;

  // ETA State
  AppointmentEtaInfo _etaInfo = AppointmentEtaInfo.empty();
  AppointmentEtaInfo get etaInfo => _etaInfo;

  // Replay Mode State
  bool _isReplayMode = false;
  DateTime? _simulatedTime;
  DateTime? _scenarioStart;
  DateTime? _scenarioEnd;
  Timer? _replayTimer;
  double _replaySpeed = 1.0;
  List<dynamic> _currentTrace = [];
  int _replayIndex = 0;
  String _currentScenarioName = "";

  // Original State Backup (to restore after replay)
  RiskState? _liveRisk;
  List<Intervention>? _liveInterventions;

  RiskState get currentRisk => _currentRisk;
  List<ContextSnapshot> get snapshots => _snapshots;
  List<Intervention> get interventions => _interventions;
  List<TimelineEvent> get timelineEvents => _timelineEvents;
  List<String> get rawMessages => _rawMessages;
  bool get isLive => _isLive;
  bool get isReplayMode => _isReplayMode;
  String get currentScenarioName => _currentScenarioName;
  DateTime? get simulatedTime => _simulatedTime;
  double get replaySpeed => _replaySpeed;

  // Risk Summary State (OpenClaw Heartbeat)
  int _risksNext90Min = 0;
  List<String> _activeRiskTypes = [];
  DateTime? _lastHeartbeatTime;
  RiskSnapshot? _currentRiskSnapshot;
  Map<String, dynamic>? _currentFutures;

  int get risksNext90Min => _risksNext90Min;
  List<String> get activeRiskTypes => _activeRiskTypes;
  DateTime? get lastHeartbeatTime => _lastHeartbeatTime;
  RiskSnapshot? get currentRiskSnapshot => _currentRiskSnapshot;
  Map<String, dynamic>? get currentFutures => _currentFutures;

  int get replayProgress {
    if (_scenarioStart == null ||
        _scenarioEnd == null ||
        _simulatedTime == null)
      return 0;
    final total = _scenarioEnd!.difference(_scenarioStart!).inSeconds;
    final current = _simulatedTime!.difference(_scenarioStart!).inSeconds;
    return ((current / total) * 100).clamp(0, 100).toInt();
  }

  String get userId => _userId;

  AppState() {
    _initLocalData();
    _generateMockData();
    _connectWebSocket();
    _initContextIngestion();
    // Keep internal simulation for fallback or UI stability
    _startSimulatedStream();
    
    // Initial ETA fetch
    fetchAppointmentEta();
    
    // Periodic ETA refresh
    Timer.periodic(const Duration(minutes: 2), (timer) {
      if (!_isReplayMode) fetchAppointmentEta();
    });
  }

  Future<void> _initLocalData() async {
    // Load initial state from DB
    final latestSnapshots = await _localRepo.getLatestSnapshots(20);
    // Convert back to models if needed, for now just priming the pump
    debugPrint(
      '[Pulse AppState] Local data initialized: ${latestSnapshots.length} snapshots found',
    );
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
      if (_isReplayMode) return; // Ignore live messages during replay

      debugPrint('[Pulse] Received: ${data['type']}');
      _processPulseEvent(data);
    } catch (e) {
      debugPrint('[Pulse] Error parsing message: $e');
    }

    notifyListeners();
  }

  void _processPulseEvent(Map<String, dynamic> data, {bool isReplay = false}) {
    final type = data['type'] as String?;
    final timestampStr = data['timestamp'] as String?;
    final timestamp = timestampStr != null
        ? DateTime.parse(timestampStr)
        : DateTime.now();

    // Persist to Local DB (Only if live)
    if (!isReplay) {
      if (type == 'context.updated') {
        _timelineEvents.insert(
          0,
          TimelineEvent(
            id: data['eventId'] ?? const Uuid().v4(),
            timestamp: timestamp,
            type: 'Context',
            agent: 'Context',
            text: 'Device state snapshot ingested.',
            data: data['data'],
          ),
        );
      } else if (type == 'risk.updated') {
        final risks = data['data']?['risks'] as List<dynamic>?;
        if (risks != null && risks.isNotEmpty) {
          _timelineEvents.insert(
            0,
            TimelineEvent(
              id: data['eventId'] ?? const Uuid().v4(),
              timestamp: timestamp,
              type: 'Risk',
              agent: 'RiskEngine',
              text:
                  '${risks.length} risks detected: ${risks.map((r) => r['type']).join(", ")}',
              data: data['data'],
            ),
          );
        }
        _localRepo.saveRisk(
          timestamp.toIso8601String(),
          data['data']?['level'] ?? 'unknown',
          data,
        );
      } else if (type == 'intervention.created') {
        _localRepo.saveTimelineEvent(
          data['eventId'] ?? const Uuid().v4(),
          timestamp.toIso8601String(),
          type!,
          data,
        );
      }
    } else if (type == 'futures.updated') {
      debugPrint('[Pulse AppState] Futures update received');
      _currentFutures = data['data'];
    }

    // Update UI State
    if (type == 'risk.updated') {
      debugPrint(
        '[Pulse AppState] Risk update received for user: ${data['userId']}',
      );
      final rData = data['data'];
      if (rData != null) {
        _currentRiskSnapshot = RiskSnapshot.fromJson(rData);
        _currentRisk = RiskState(
          score: _currentRiskSnapshot!.risks.isEmpty
              ? 0.0
              : _currentRiskSnapshot!.risks
                    .map((r) => r.score)
                    .reduce((a, b) => a > b ? a : b),
          level: _parseRiskLevel(
            _currentRiskSnapshot!.risks.isEmpty
                ? 'LOW'
                : _currentRiskSnapshot!.risks[0].label.name.toUpperCase(),
          ),
          timestamp: timestamp,
          reasons: _currentRiskSnapshot!.risks.map((r) => r.summary).toList(),
          history: [],
        );
      }
    } else if (type == 'intervention.created') {
      final intv = data['data'];
      if (intv != null) {
        final intvId =
            data['eventId'] ?? "int_${DateTime.now().millisecondsSinceEpoch}";
        _timelineEvents.insert(
          0,
          TimelineEvent(
            id: intvId,
            timestamp: timestamp,
            type: 'Action',
            agent: 'Planner',
            text: '${intv['headline']}: ${intv['body']}',
            data: intv,
          ),
        );
        _interventions.insert(
          0,
          Intervention(
            id: intvId,
            title: intv['headline'] ?? "New Intervention",
            description: intv['body'] ?? "",
            type: "System",
            priority: 1,
            status: InterventionStatus.pending,
            steps: [],
            impact: "",
            reason: "",
            createdAt: timestamp,
          ),
        );
      }
    } else if (type == 'heartbeat.tick') {
      // Only process ticks for our current user
      if (data['userId'] != null && data['userId'] != _userId) return;

      debugPrint(
        '[Pulse AppState] Heartbeat tick: risksNext90Min=${data['data']?['risksNext90Min']}',
      );
      _lastHeartbeatTime = timestamp;
      final hData = data['data'];
      if (hData != null && hData['risksNext90Min'] != null) {
        _risksNext90Min = hData['risksNext90Min'];
      }
    } else if (type == 'graph.updated') {
      if (data['userId'] != null && data['userId'] != _userId) return;

      final gData = data['data'];
      debugPrint(
        '[Pulse AppState] Graph update: risksNext90Min=${gData?['totalRisksNext90Min']}',
      );
      if (gData != null) {
        _risksNext90Min = gData['totalRisksNext90Min'] ?? 0;
        final risks = gData['risks'] as List<dynamic>?;
        if (risks != null) {
          _activeRiskTypes = risks.map((r) => r['type'].toString()).toList();
        }
      }
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
      // Use the instance userId

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
        
        // Refresh ETA after successful context ingestion
        fetchAppointmentEta();

        // Save to Local DB
        await _localRepo.saveSnapshot(
          payload['id'] as String,
          payload['timestamp'] as String,
          _mapReason(reason),
          payload,
        );
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

  // --- Import / Export Actions ---

  Future<String> exportData() async {
    final path = await _localRepo.exportToJson();
    debugPrint('[Pulse AppState] Data exported to: $path');
    return path;
  }

  Future<void> importData(String json) async {
    await _localRepo.importFromJson(json);
    await _initLocalData();
    notifyListeners();
  }

  // --- Replay Mode Engine ---

  void startReplay(String name, List<dynamic> trace, {double speed = 1.0}) {
    stopReplay(); // Clear existing

    // Backup live state
    _liveRisk = _currentRisk;
    _liveInterventions = List.from(_interventions);

    _isReplayMode = true;
    _currentScenarioName = name;
    _currentTrace = trace;
    _replaySpeed = speed;
    _replayIndex = 0;

    if (_currentTrace.isEmpty) return;

    // Determine bounds
    _scenarioStart = DateTime.parse(_currentTrace.first['timestamp']);
    _scenarioEnd = DateTime.parse(_currentTrace.last['timestamp']);
    _simulatedTime = _scenarioStart;

    debugPrint('[Pulse Replay] Starting "$name" at ${speed}x');

    _resumeTimer();
    notifyListeners();
  }

  Future<List<dynamic>> fetchSuggestedActions(String riskType, {String? nodeId}) async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse(
        'http://$host:8080/api/planner/suggested-actions?userId=$_userId&riskType=$riskType&nodeId=${nodeId ?? ""}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error fetching suggested actions: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> fetchGraphExplanation(String nodeId) async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse(
        'http://$host:8080/api/graph/explain/$nodeId?X-User-Id=$_userId',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error fetching graph explanation: $e');
    }
    return null;
  }

  void _resumeTimer() {
    _replayTimer?.cancel();
    _replayTimer = Timer.periodic(
      const Duration(
        milliseconds: 100,
      ), // High frequency update for smooth clock
      (timer) {
        if (!_isReplayMode) {
          timer.cancel();
          return;
        }

        // Advance simulated time based on speed (100ms * speed)
        _simulatedTime = _simulatedTime!.add(
          Duration(milliseconds: (100 * _replaySpeed).toInt()),
        );

        // Process all events that have occurred up to this simulated time
        bool stateChanged = false;
        while (_replayIndex < _currentTrace.length) {
          final event = _currentTrace[_replayIndex];
          final eventTime = DateTime.parse(event['timestamp']);

          if (eventTime.isBefore(_simulatedTime!) ||
              eventTime.isAtSameMomentAs(_simulatedTime!)) {
            _processPulseEvent(
              Map<String, dynamic>.from(event),
              isReplay: true,
            );
            _replayIndex++;
            stateChanged = true;
          } else {
            break;
          }
        }

        if (_simulatedTime!.isAfter(_scenarioEnd!) ||
            _simulatedTime!.isAtSameMomentAs(_scenarioEnd!)) {
          _replayTimer?.cancel();
        }

        notifyListeners();
      },
    );
  }

  void seekToProgress(double progress) {
    if (!_isReplayMode || _scenarioStart == null || _scenarioEnd == null)
      return;

    _replayTimer?.cancel();

    final totalSeconds = _scenarioEnd!.difference(_scenarioStart!).inSeconds;
    final targetSeconds = (totalSeconds * (progress / 100)).toInt();
    _simulatedTime = _scenarioStart!.add(Duration(seconds: targetSeconds));

    // Reset simulation state
    _interventions = [];
    _timelineEvents = [];
    _currentRiskSnapshot = null;
    _currentFutures = null;
    _replayIndex = 0;

    // Replay all events up to the target time instantly
    for (var i = 0; i < _currentTrace.length; i++) {
      final event = _currentTrace[i];
      final eventTime = DateTime.parse(event['timestamp']);
      if (eventTime.isBefore(_simulatedTime!) ||
          eventTime.isAtSameMomentAs(_simulatedTime!)) {
        _processPulseEvent(Map<String, dynamic>.from(event), isReplay: true);
        _replayIndex = i + 1;
      } else {
        break;
      }
    }

    _resumeTimer();
    notifyListeners();
  }

  void stopReplay() {
    _replayTimer?.cancel();
    _isReplayMode = false;
    _simulatedTime = null;
    _scenarioStart = null;
    _scenarioEnd = null;
    _replayIndex = 0;

    // Restore live state
    if (_liveRisk != null) _currentRisk = _liveRisk!;
    if (_liveInterventions != null) _interventions = _liveInterventions!;

    notifyListeners();
  }

  void setReplaySpeed(double speed) {
    _replaySpeed = speed;
    if (_isReplayMode) {
      _resumeTimer();
    }
    notifyListeners();
  }

  RiskLevel _parseRiskLevel(String? level) {
    switch (level?.toLowerCase()) {
      case 'safe':
        return RiskLevel.safe;
      case 'low':
      case 'med':
      case 'riskforming':
      case 'risk_forming':
        return RiskLevel.riskForming;
      case 'high':
      case 'critical':
      case 'highrisk':
      case 'high_risk':
        return RiskLevel.highRisk;
      default:
        return RiskLevel.safe;
    }
  }

  Future<void> fetchAppointmentEta() async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/routing/next-appointment-eta?userId=$_userId');
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['ok'] == true) {
          _etaInfo = AppointmentEtaInfo.fromJson(data['data']);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error fetching appointment ETA: $e');
    }
  }

  String _getBackendHost() {
    String host = 'localhost';
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // For physical devices or emulators on local network
        // Use your computer's local IP address
        host = '10.123.31.141';
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
