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
import '../services/notification_service.dart';
import '../models/risk_snapshot.dart';
import '../models/twin_graph.dart';
import '../services/storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:home_widget/home_widget.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';
import '../services/llm_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> toolsUsed;
  final List<Map<String, dynamic>> actions;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.toolsUsed = const [],
    this.actions = const [],
  });
}

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

class DayPulseRisk {
  final String type;
  final String level;
  final String label;
  final double score;
  final String? explanation;

  DayPulseRisk({
    required this.type,
    required this.level,
    required this.label,
    required this.score,
    this.explanation,
  });

  factory DayPulseRisk.fromJson(Map<String, dynamic> json) {
    return DayPulseRisk(
      type: json['type'] ?? 'unknown',
      level: json['level'] ?? 'low',
      label: (json['type'] ?? 'INFO').toString().toUpperCase(),
      score: (json['score'] as num? ?? 0.0).toDouble(),
      explanation: json['explanation'],
    );
  }
}

class DayPulseBlock {
  final String eventId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String type; // 'event' | 'routine' | 'act'
  final String? category; // 'sleep' | 'study' | 'commute' | 'buffer'
  final String? locationText;
  final int? etaMinutes;
  final double? batteryAtStart;
  final List<int>? days;
  final List<DayPulseRisk> risks;
  final Map<String, dynamic>? suggestion;
  final Map<String, dynamic>? startLocation;
  final bool isDeleted;

  DayPulseBlock({
    required this.eventId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.type,
    this.category,
    this.locationText,
    this.etaMinutes,
    this.batteryAtStart,
    this.days,
    required this.risks,
    this.suggestion,
    this.startLocation,
    this.isDeleted = false,
  });

  factory DayPulseBlock.fromJson(Map<String, dynamic> json) {
    return DayPulseBlock(
      eventId: json['eventId'],
      title: json['title'],
      startTime: DateTime.parse(json['startTime']).toLocal(),
      endTime: DateTime.parse(json['endTime']).toLocal(),
      type: json['type'] ?? 'event',
      category: json['category'],
      locationText: json['locationText'],
      etaMinutes: json['etaMinutes'],
      batteryAtStart: (json['batteryAtStart'] as num?)?.toDouble(),
      days: json['days'] != null ? List<int>.from(json['days']) : null,
      risks: (json['risks'] as List? ?? [])
          .map((r) => DayPulseRisk.fromJson(r))
          .toList(),
      suggestion: json['suggestion'],
      startLocation: json['startLocation'],
      isDeleted: json['isDeleted'] ?? false,
    );
  }
}

class AppState extends ChangeNotifier {
  static const _eventChannel = EventChannel('notifications_stream');
  static const _methodChannel = MethodChannel('battery_optimization');

  final ContextServices _contextServices = ContextServices();
  final LocalRepository _localRepo = LocalRepository();
  DeviceContext _deviceContext = DeviceContext.initial();
  String _userId = "31d1ff89-6b28-44e0-bea3-7c61debfd1b6";

  final LlmService _llmService = LlmService();



  // Notification getters
  List<NotificationInfo> get notifications => _deviceContext.notifications;

  List<NotificationInfo> get urgentNotifications => notifications
      .where(
        (n) =>
            n.category == 'URGENT_OTP' ||
            n.text.toLowerCase().contains('otp') ||
            n.text.toLowerCase().contains('code'),
      )
      .toList();

  List<NotificationInfo> get importantNotifications => notifications
      .where(
        (n) =>
            n.category == 'IMPORTANT_SENDER' ||
            n.appName.toLowerCase().contains('slack') ||
            n.appName.toLowerCase().contains('whatsapp'),
      )
      .toList();

  List<NotificationInfo> get noisyNotifications => notifications
      .where(
        (n) =>
            !urgentNotifications.contains(n) &&
            !importantNotifications.contains(n),
      )
      .toList();

  void initDoomscrollMonitor() {
    _doomscrollCheckTimer?.cancel();
    _doomscrollCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkDoomscrolling();
    });
  }

  Future<void> _checkDoomscrolling() async {
    // 1. Check if there's an active scheduled activity
    final now = DateTime.now();
    DayPulseBlock? currentActivity;
    try {
      currentActivity = _dayPulseBlocks.firstWhere(
        (b) =>
            b.startTime.isBefore(now) &&
            b.endTime.isAfter(now) &&
            b.type != 'buffer' &&
            !b.title.toLowerCase().contains('sleep'),
      );
    } catch (_) {
      // No active activity
      _lastSocialStartTime = null;
      _hasSentDoomscrollAlert = false;
      return;
    }

    // 2. Check current foreground app
    final startCheck = now.subtract(const Duration(minutes: 2));
    final usage = await getAppUsage(startCheck, now);

    if (usage.isNotEmpty) {
      final latest = usage.last;
      final packageName = latest['packageName'] as String;

      if (doomscrollApps.contains(packageName)) {
        if (_lastSocialStartTime == null) {
          _lastSocialStartTime = now;
        } else {
          final duration = now.difference(_lastSocialStartTime!);
          if (duration.inMinutes >= 5 && !_hasSentDoomscrollAlert) {
            NotificationService().showPulseNotification(
              title: "🚨 Doomscroll Alert",
              body:
                  "You're currently scheduled for '${currentActivity.title}', but you've been on ${packageName.split('.').last} for ${duration.inMinutes} mins. Focus up!",
              state: "CRITICAL",
            );
            _hasSentDoomscrollAlert = true;

            _timelineEvents.insert(
              0,
              TimelineEvent(
                id: const Uuid().v4(),
                timestamp: now,
                type: 'Intervention',
                agent: 'Pulse Guardian',
                text: 'Doomscroll alert sent for ${currentActivity.title}',
                data: {'app': packageName, 'duration': duration.inMinutes},
              ),
            );
            notifyListeners();
          }
        }
      } else {
        _lastSocialStartTime = null;
        _hasSentDoomscrollAlert = false;
      }
    }
  }

  // Surge detection window
  final int _surgeWindowMs = 60000; // 60 seconds
  final int _surgeThreshold = 5;
  bool _isSurgeActive = false;
  bool get isSurgeActive => _isSurgeActive;

  Timer? _summaryTimer;
  bool _isSummarizing = false;
  bool get isSummarizing => _isSummarizing;

  String _llmHighlight = '';
  String _llmDigest = '';
  List<String> _llmActionItems = [];
  DateTime? _llmTimestamp;
  DateTime? _lastSummarizedAt;

  String get llmHighlight => _llmHighlight;
  String get llmDigest => _llmDigest;
  List<String> get llmActionItems => _llmActionItems;
  DateTime? get llmTimestamp => _llmTimestamp;

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
  String _selectedScenarioId = "RECOMMENDED";
  Map<String, dynamic>? _lastPlannerDecision;
  TwinGraph? _twinGraph;
  String? _twinSummary;
  bool _isTwinSummarizing = false;

  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;

  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  int get risksNext90Min => _risksNext90Min;
  List<String> get activeRiskTypes => _activeRiskTypes;
  DateTime? get lastHeartbeatTime => _lastHeartbeatTime;
  RiskSnapshot? get currentRiskSnapshot => _currentRiskSnapshot;
  Map<String, dynamic>? get currentFutures => _currentFutures;
  String get selectedScenarioId => _selectedScenarioId;
  Map<String, dynamic>? get lastPlannerDecision => _lastPlannerDecision;
  TwinGraph? get twinGraph => _twinGraph;
  String? get twinSummary => _twinSummary;
  bool get isTwinSummarizing => _isTwinSummarizing;
  Map<String, dynamic>? get proposedCommAction => _proposedCommAction;
  List<DayPulseBlock> get dayPulseBlocks => _dayPulseBlocks;

  final Set<String> _acceptedActionIds = {};
  final Set<String> _dismissedActionIds = {};
  Map<String, dynamic>? _proposedCommAction;
  List<DayPulseBlock> _dayPulseBlocks = [];
  bool _isDayPulseProposed = false;

  List<ChatMessage> _chatMessages = [];
  List<ChatMessage> get chatMessages => _chatMessages;
  bool _isChatLoading = false;
  bool get isChatLoading => _isChatLoading;

  Future<List<Map<String, dynamic>>> getAppUsage(
    DateTime start,
    DateTime end,
  ) async {
    return _contextServices.getAppUsage(start, end);
  }

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Timer? _doomscrollCheckTimer;
  String? _currentForegroundApp;
  DateTime? _lastSocialStartTime;
  bool _hasSentDoomscrollAlert = false;

  static const List<String> doomscrollApps = [
    'com.instagram.android',
    'com.twitter.android',
    'com.zhiliaoapp.musically', // TikTok
    'com.reddit.frontpage',
    'com.facebook.katana',
    'com.google.android.youtube',
    'com.snapchat.android',
  ];

  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        const config = RecordConfig(encoder: AudioEncoder.aacLc);

        await _audioRecorder.start(config, path: path);
        _isRecording = true;
        notifyListeners();
        debugPrint('[Pulse AppState] Recording started: $path');
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error starting recording: $e');
    }
  }

  Future<void> stopRecordingAndSend() async {
    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      notifyListeners();

      if (path != null) {
        debugPrint('[Pulse AppState] Recording stopped: $path');
        await _transcribeAndSend(path);
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error stopping recording: $e');
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<void> _transcribeAndSend(String path) async {
    _isChatLoading = true;
    notifyListeners();

    try {
      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/chat/transcribe');

      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(_authHeaders);
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          path,
          contentType: MediaType('audio', 'mpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['data']['text'] as String;
        debugPrint('[Pulse AppState] Transcription success: $text');

        if (text.trim().isNotEmpty) {
          await sendChatMessage(text);
        }
      } else {
        debugPrint('[Pulse AppState] Transcription failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error transcribing audio: $e');
    } finally {
      _isChatLoading = false;
      notifyListeners();
    }
  }

  bool get isDayPulseProposed => _isDayPulseProposed;

  bool isActionAccepted(String id) => _acceptedActionIds.contains(id);
  bool isActionDismissed(String id) => _dismissedActionIds.contains(id);

  void acceptAction(Map<String, dynamic> action) {
    final id = action['id'];
    _acceptedActionIds.add(id);
    _dismissedActionIds.remove(id);

    // Emit timeline event
    _timelineEvents.insert(
      0,
      TimelineEvent(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        type: 'Action',
        agent: 'User',
        text: 'Accepted: ${action['title']}',
        data: action,
      ),
    );

    debugPrint('[Pulse AppState] Action accepted: $id');
    notifyListeners();

    // Optional: Call backend to sync
    _syncActionToBackend(id, 'accepted');
  }

  void dismissAction(Map<String, dynamic> action) {
    final id = action['id'];
    _dismissedActionIds.add(id);
    _acceptedActionIds.remove(id);

    debugPrint('[Pulse AppState] Action dismissed: $id');
    notifyListeners();

    _syncActionToBackend(id, 'dismissed');
  }

  Future<void> _syncActionToBackend(String actionId, String status) async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse(
        'http://$host:8080/api/planner/interventions/status',
      );
      await http.post(
        url,
        body: json.encode({
          'userId': _userId,
          'deviceId': _userId,
          'actionId': actionId,
          'status': status,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        headers: _authHeaders,
      );
    } catch (e) {
      debugPrint('[Pulse AppState] Error syncing action status: $e');
    }
  }

  void selectScenario(String id) {
    _selectedScenarioId = id;
    notifyListeners();

    // Sync to backend
    _syncScenarioSelection(id);
  }

  Future<void> _syncScenarioSelection(String scenarioId) async {
    try {
      final host = _getBackendHost();

      // 1. Persist selection
      final selectUrl = Uri.parse(
        'http://$host:8080/api/planner/scenario/select',
      );
      await http.post(
        selectUrl,
        headers: _authHeaders,
        body: jsonEncode({
          'userId': _userId,
          'deviceId': _userId,
          'scenarioId': scenarioId,
        }),
      );

      // 2. Fetch updated decision/actions based on this scenario
      // Map A/B/C to internal IDs if necessary, but the screen already passes RECOMMENDED etc.
      final scenarioUrl = Uri.parse(
        'http://$host:8080/api/planner/scenario/$scenarioId?userId=$_userId&deviceId=$_userId',
      );
      final response = await http.get(scenarioUrl, headers: _authHeaders);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _lastPlannerDecision = data['data'];
        debugPrint(
          '[Pulse AppState] Scenario decision updated for: $scenarioId',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error syncing scenario selection: $e');
    }
  }

  Future<void> fetchDayPulse() async {
    try {
      final host = _getBackendHost();
      final date = DateTime.now().toIso8601String().split('T')[0];
      final url = Uri.parse(
        'http://$host:8080/api/day-pulse?userId=$_userId&deviceId=$_userId&date=$date',
      );
      final response = await http.get(url, headers: _authHeaders);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List blocks = data['data']['blocks'];
        _dayPulseBlocks = blocks
            .map((b) => DayPulseBlock.fromJson(b))
            .where((b) => !b.isDeleted)
            .toList();
        _isDayPulseProposed = data['data']['isProposed'] ?? false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error fetching daily pulse: $e');
    }
  }

  Future<void> modifyDayPulse(
    String eventId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/day-pulse/modify');
      final date = DateTime.now().toIso8601String().split('T')[0];
      final response = await http.post(
        url,
        headers: _authHeaders,
        body: json.encode({
          'userId': _userId,
          'deviceId': _userId,
          'eventId': eventId,
          'updates': updates,
          'isRecurring': updates['isRecurring'],
          'days': updates['days'],
          'date': date,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List blocks = data['data']['blocks'];
        _dayPulseBlocks = blocks
            .map((b) => DayPulseBlock.fromJson(b))
            .where((b) => !b.isDeleted)
            .toList();
        _isDayPulseProposed = data['data']['isProposed'] ?? false;
        notifyListeners();

        fetchTwinGraph();
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error modifying daily pulse: $e');
    }
  }

  Future<void> addDayPulseEvent(
    String title,
    DateTime start,
    DateTime end, {
    String? location,
    String? category,
    bool isRecurring = false,
    List<int>? days,
    Map<String, dynamic>? startLocation,
    Map<String, dynamic>? destinationLocation,
  }) async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/day-pulse/add');

      final date = DateTime.now().toIso8601String().split('T')[0];
      final response = await http.post(
        url,
        headers: _authHeaders,
        body: json.encode({
          'userId': _userId,
          'deviceId': _userId,
          'event': {
            'id': 'manual_${DateTime.now().millisecondsSinceEpoch}',
            'title': title,
            'start_time': start.toUtc().toIso8601String(),
            'end_time': end.toUtc().toIso8601String(),
            'location_text': location,
            'start_location': startLocation,
            'destination_location': destinationLocation,
          },
          'isRecurring': isRecurring,
          'days': days,
          'category': category,
          'date': date,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List blocks = data['data']['blocks'];
        _dayPulseBlocks = blocks.map((b) => DayPulseBlock.fromJson(b)).toList();
        _isDayPulseProposed = data['data']['isProposed'] ?? false;
        notifyListeners();
        fetchTwinGraph();
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error adding event: $e');
    }
  }

  Future<void> planBriefChargingStop() async {
    // 1. Find gap after current time
    DateTime now = _isReplayMode
        ? (_simulatedTime ?? DateTime.now())
        : DateTime.now();

    // Sort blocks by start time to be safe
    final sortedBlocks = List<DayPulseBlock>.from(_dayPulseBlocks);
    sortedBlocks.sort((a, b) => a.startTime.compareTo(b.startTime));

    DateTime? gapStart;
    DateTime? gapEnd;

    // We want a gap after 'now'
    DateTime lastEnd = now;

    for (var block in sortedBlocks) {
      if (block.endTime.isBefore(now)) {
        lastEnd = block.endTime;
        continue;
      }

      if (block.startTime.isAfter(lastEnd.add(const Duration(minutes: 10)))) {
        // Found a gap!
        // The gap starts at either lastEnd or now, whichever is later.
        DateTime potentialStart = lastEnd.isAfter(now) ? lastEnd : now;
        if (block.startTime.difference(potentialStart).inMinutes >= 20) {
          gapStart = potentialStart.add(
            const Duration(minutes: 2),
          ); // Small buffer
          gapEnd = gapStart.add(const Duration(minutes: 30));
          break;
        }
      }
      lastEnd = block.endTime;
    }

    // If no gap found between events, add it after the last event
    if (gapStart == null) {
      gapStart = lastEnd.isAfter(now) ? lastEnd : now;
      gapStart = gapStart.add(const Duration(minutes: 5));
      gapEnd = gapStart.add(const Duration(minutes: 30));
    }

    // 2. Add event
    await addDayPulseEvent(
      "Brief Charging Stop",
      gapStart!,
      gapEnd!,
      category: "commute",
    );

    // 3. Update Risk
    await fetchTwinGraph();
  }

  void stopReplay() {
    _replayTimer?.cancel();
    _isReplayMode = false;
    _simulatedTime = null;
    notifyListeners();
  }

  Future<void> deleteDayPulseItem(String eventId, bool isRoutine) async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/day-pulse/delete');
      final date = DateTime.now().toIso8601String().split('T')[0];
      final response = await http.post(
        url,
        headers: _authHeaders,
        body: json.encode({
          'userId': _userId,
          'deviceId': _userId,
          'eventId': eventId,
          'isRoutine': isRoutine,
          'date': date,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List blocks = data['data']['blocks'];
        _dayPulseBlocks = blocks
            .map((b) => DayPulseBlock.fromJson(b))
            .where((b) => !b.isDeleted)
            .toList();
        _isDayPulseProposed = data['data']['isProposed'] ?? false;
        notifyListeners();
        fetchTwinGraph();
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error deleting item: $e');
    }
  }

  Future<void> optimizeDayPulse() async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/day-pulse/optimize');
      final response = await http.post(
        url,
        headers: _authHeaders,
        body: json.encode({
          'userId': _userId,
          'deviceId': _userId,
          'date': DateTime.now().toIso8601String().split('T')[0],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List blocks = data['data']['blocks'];
        _dayPulseBlocks = blocks.map((b) => DayPulseBlock.fromJson(b)).toList();
        _isDayPulseProposed = data['data']['isProposed'] ?? false;
        notifyListeners();
        fetchTwinGraph();
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error optimizing daily pulse: $e');
    }
  }

  Future<void> persistDayPulse() async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/day-pulse/persist');
      final date = DateTime.now().toIso8601String().split('T')[0];

      final response = await http.post(
        url,
        headers: _authHeaders,
        body: json.encode({
          'userId': _userId,
          'deviceId': _userId,
          'date': date,
          'blocks': _dayPulseBlocks
              .map(
                (b) => {
                  'eventId': b.eventId,
                  'title': b.title,
                  'startTime': b.startTime.toIso8601String(),
                  'endTime': b.endTime.toIso8601String(),
                  'locationText': b.locationText,
                  'isProposed': true,
                  'isDeleted': false,
                },
              )
              .toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List blocks = data['data']['blocks'];
        _dayPulseBlocks = blocks.map((b) => DayPulseBlock.fromJson(b)).toList();
        _isDayPulseProposed = false;
        notifyListeners();
        fetchTwinGraph();
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error persisting daily pulse: $e');
    }
  }

  Future<void> discardDayPulseProposed() async {
    _isDayPulseProposed = false;
    await fetchDayPulse();
  }

  Future<void> sendChatMessage(String message) async {
    if (message.trim().isEmpty) return;

    final userMsg = ChatMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    );
    _chatMessages.add(userMsg);
    _isChatLoading = true;
    notifyListeners();

    try {
      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/chat/message');

      final history = _chatMessages
          .take(_chatMessages.length - 1)
          .map(
            (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
          )
          .toList();

      final response = await http.post(
        url,
        headers: _authHeaders,
        body: jsonEncode({
          'userId': _userId,
          'message': message,
          'history': history,
          'currentTime': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        final rawText = data['text'] as String;

        // Parse actions: [Action: Title | ID | Description? | Impact?]
        final actionRegex = RegExp(r'\[Action: (.*?)\]');
        final matches = actionRegex.allMatches(rawText);
        final actions = matches.map((m) {
          final parts = m.group(1)!.split('|').map((s) => s.trim()).toList();
          return {
            'title': parts.isNotEmpty ? parts[0] : '',
            'id': parts.length > 1 ? parts[1] : '',
            'description': parts.length > 2 ? parts[2] : '',
            'impact': parts.length > 3 ? parts[3] : '',
          };
        }).toList();

        final cleanText = rawText.replaceAll(actionRegex, '').trim();

        final botMsg = ChatMessage(
          text: cleanText,
          isUser: false,
          timestamp: DateTime.now(),
          toolsUsed: List<String>.from(data['toolsUsed'] ?? []),
          actions: actions,
        );
        _chatMessages.add(botMsg);

        // Auto-refresh relevant data if agent modified state
        if (botMsg.toolsUsed.contains('addDailyEvent') ||
            botMsg.toolsUsed.contains('applyAction')) {
          fetchDayPulse();
        }
        if (botMsg.toolsUsed.contains('updateTwinGraph')) {
          fetchTwinGraph();
        }
      } else {
        _chatMessages.add(
          ChatMessage(
            text: "Sorry, I'm having trouble connecting right now.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Chat error: $e');
      _chatMessages.add(
        ChatMessage(
          text:
              "Error connecting to Pulse intelligence. Please check your connection.",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      _isChatLoading = false;
      notifyListeners();
    }
  }

  void initiateChat(String message) {
    _currentTabIndex = 4; // Chat screen index
    notifyListeners();
    sendChatMessage(message);
  }

  // Pulse snapshot (Day 12 — persistent widget source of truth)
  // Seeded with a visible fallback so the bar renders immediately
  Map<String, dynamic> _pulseSnapshot = {
    'state': 'NOMINAL',
    'topRiskScore': 0.0,
    'notificationContent': {
      'title': 'Pulse active',
      'subtitle': 'Monitoring your context…',
      'urgency': 'low',
    },
    'notificationDigest': {
      'highlight': 'Connecting to server…',
      'urgent': [],
      'important': [],
      'noiseCount': 0,
    },
    'nextAction': null,
  };
  int _lastPulseSnapshotVersion = -1;

  Map<String, dynamic> get pulseSnapshot => _pulseSnapshot;

  String get userId => _userId;

  AppState() {
    _init();
    initDoomscrollMonitor();
  }

  Future<void> _init() async {
    _userId = "31d1ff89-6b28-44e0-bea3-7c61debfd1b6";
    notifyListeners();

    _startListeningNotifications();
    _initLocalData();
    _generateMockData();
    _initNotificationService();
    _connectWebSocket();
    _initContextIngestion();
    _startPeriodicSummarization();

    // Initial ETA fetch
    fetchAppointmentEta();

    // Periodic ETA refresh
    Timer.periodic(const Duration(minutes: 2), (timer) {
      fetchAppointmentEta();
    });
  }

  Future<void> _initNotificationService() async {
    final ns = NotificationService();
    await ns.init();
    await ns.requestPermissions();
    _updateNativeNotification(); // show initial seeded state
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
          isInBatterySaveMode: info.isInBatterySaveMode,
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

    _initCalendarIngestion();
  }

  void _initCalendarIngestion() async {
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
  }

  void _startListeningNotifications() {
    _eventChannel.receiveBroadcastStream().listen(
      (event) {
        try {
          final data = Map<String, dynamic>.from(event);
          final notif = NotificationInfo.fromMap(data);

          // Ignore system UI updates
          if (notif.packageName == 'com.android.systemui') return;

          _deviceContext.notifications.insert(0, notif);
          if (_deviceContext.notifications.length > 100) {
            _deviceContext.notifications.removeLast();
          }

          _checkForSurge();
          notifyListeners();

          // Also sync to backend if needed
          _sendContextSnapshot("notification_received");
        } catch (e) {
          debugPrint('[Pulse AppState] Error parsing notification: $e');
        }
      },
      onError: (error) {
        debugPrint('[Pulse AppState] Notification stream error: $error');
      },
    );
  }

  // Permission handling methods from testing app
  Future<void> requestOverlayPermission() async {
    await FlutterOverlayWindow.requestPermission();
  }

  Future<void> requestBatteryOptimizationDisable() async {
    try {
      await _methodChannel.invokeMethod('requestDisable');
    } catch (e) {
      debugPrint(
        '[Pulse AppState] Failed to request battery optimization disable: $e',
      );
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _methodChannel.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('[Pulse AppState] Failed to open notification settings: $e');
    }
  }

  void _startPeriodicSummarization() {
    _summaryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      debugPrint('[Pulse AppState] 5-minute periodic summarization triggered.');
      _triggerSummarization();
    });
  }

  void _checkForSurge() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final recentCount = notifications
        .where(
          (n) => (now - n.timestamp.millisecondsSinceEpoch) < _surgeWindowMs,
        )
        .length;

    if (recentCount >= _surgeThreshold && !_isSurgeActive) {
      _isSurgeActive = true;
      notifyListeners();
      _triggerSummarization(surgeOnly: true);
    } else if (recentCount < _surgeThreshold && _isSurgeActive) {
      _isSurgeActive = false;
      notifyListeners();
    }
  }

  Future<void> manualRequestSummary() async {
    debugPrint(
      '[Pulse AppState] Manual summarization requested (forcing all).',
    );
    await _triggerSummarization(forceAll: true);
  }

  Future<void> _triggerSummarization({
    bool surgeOnly = false,
    bool forceAll = false,
  }) async {
    if (_isSummarizing) return;
    if (notifications.isEmpty) {
      debugPrint('[Pulse AppState] No notifications to summarize.');
      return;
    }

    _isSummarizing = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      List<NotificationInfo> batchToSummarize;

      if (forceAll) {
        batchToSummarize = List.of(notifications);
      } else if (surgeOnly) {
        batchToSummarize = notifications
            .where(
              (n) =>
                  (nowMs - n.timestamp.millisecondsSinceEpoch) < _surgeWindowMs,
            )
            .toList();
      } else if (_lastSummarizedAt == null) {
        batchToSummarize = List.of(notifications);
      } else {
        batchToSummarize = notifications
            .where((n) => n.timestamp.isAfter(_lastSummarizedAt!))
            .toList();
      }

      if (batchToSummarize.isEmpty) {
        debugPrint('[Pulse AppState] No NEW notifications since last summary.');
        _llmHighlight = 'No new notifications since last summary.';
        _llmDigest = '';
        _llmActionItems = [];
        _llmTimestamp = now;
        _isSummarizing = false;
        notifyListeners();
        return;
      }

      debugPrint(
        '[Pulse AppState] Summarizing ${batchToSummarize.length} notifications (forceAll: $forceAll)',
      );

      final summary = await _llmService.summarizeSurge(batchToSummarize);

      _llmHighlight = summary['highlight'] as String? ?? '';
      _llmDigest = summary['digest'] as String? ?? '';
      _llmActionItems =
          (summary['actionItems'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      _llmTimestamp = now;
      _lastSummarizedAt = now;

      final bool isOverlayAllowed =
          await FlutterOverlayWindow.isPermissionGranted();
      if (isOverlayAllowed && (surgeOnly || _isSurgeActive)) {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: "Pulse Digest",
          overlayContent: _llmHighlight,
          flag: OverlayFlag.focusPointer,
          alignment: OverlayAlignment.center,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.none,
          height: WindowSize.matchParent,
          width: WindowSize.matchParent,
          startPosition: const OverlayPosition(0, 0),
        );

        await FlutterOverlayWindow.shareData(
          jsonEncode({
            'highlight': _llmHighlight,
            'actionItems': _llmActionItems,
            'digest': _llmDigest,
            'isSurge': surgeOnly || _isSurgeActive,
          }),
        );
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Summarization failed: $e');
    } finally {
      _isSummarizing = false;
      notifyListeners();
    }
  }

  String _classifyNotification(
    String? title,
    String? text,
    String packageName,
  ) {
    final t = (title ?? "").toLowerCase();
    final txt = (text ?? "").toLowerCase();
    final pkg = packageName.toLowerCase();

    // OTP detection
    if (txt.contains("otp") ||
        txt.contains("verification code") ||
        txt.contains("is your code") ||
        t.contains("otp")) {
      return "URGENT_OTP";
    }

    // Important Senders (Heuristic based on app type)
    if (pkg.contains("slack") ||
        pkg.contains("teams") ||
        pkg.contains("whatsapp") ||
        pkg.contains("messenger")) {
      return "IMPORTANT_SENDER";
    }

    // Noisy Groups / Social
    if (t.contains("group") ||
        pkg.contains("instagram") ||
        pkg.contains("facebook") ||
        pkg.contains("tiktok") ||
        pkg.contains("youtube")) {
      return "NOISY_GROUP";
    }

    return "IGNORABLE";
  }

  Map<String, dynamic> _generateNotificationDigest() {
    final windowMinutes = 60;
    final now = DateTime.now();
    final recent = _deviceContext.notifications
        .where((n) => now.difference(n.timestamp).inMinutes <= windowMinutes)
        .toList();

    final counts = {
      "URGENT_OTP": 0,
      "IMPORTANT_SENDER": 0,
      "NOISY_GROUP": 0,
      "IGNORABLE": 0,
    };

    final Map<String, Map<String, dynamic>> threads = {};

    for (var n in recent) {
      counts[n.category] = (counts[n.category] ?? 0) + 1;
      final sender = n.title ?? "Unknown";
      if (!threads.containsKey(sender)) {
        threads[sender] = {
          "sender": sender,
          "packageName": n.packageName,
          "count": 0,
          "category": n.category,
        };
      }
      threads[sender]!["count"]++;
    }

    final topThreads = threads.values.toList()
      ..sort((a, b) => (b["count"] as int).compareTo(a["count"] as int));

    return {
      "summary_window_minutes": windowMinutes,
      "total_count": recent.length,
      "by_category": counts,
      "top_threads": topThreads.take(8).toList(),
    };
  }

  void _syncPulseSnapshot() {
    final digestData = _generateNotificationDigest();
    final topThreads = digestData['top_threads'] as List<dynamic>;

    final urgent = <String>[];
    final important = <String>[];

    for (var t in topThreads) {
      final label = "${t['sender']} (${t['count']})";
      if (t['category'] == 'URGENT_OTP') {
        urgent.add(label);
      } else if (t['category'] == 'IMPORTANT_SENDER') {
        important.add(label);
      }
    }

    final counts = digestData['by_category'] as Map<String, int>;
    final noiseCount =
        (counts['NOISY_GROUP'] ?? 0) + (counts['IGNORABLE'] ?? 0);

    String highlight = "Pulse monitoring active";
    if (digestData['total_count'] > 0) {
      highlight = "${digestData['total_count']} notifications summarized";
    }

    // Get real risks from the current snapshot if available
    final nextRisks =
        _currentRiskSnapshot?.risks
            .map(
              (r) => {
                'type': r.type.name,
                'label': r.summary, // Use summary as the label for the widget
                'score': r.score,
              },
            )
            .toList() ??
        [];

    _pulseSnapshot = {
      'state': _currentRisk.score >= 0.7
          ? 'CRITICAL'
          : (_currentRisk.score >= 0.4 ? 'RISK_FORMING' : 'NOMINAL'),
      'topRiskScore': _currentRisk.score,
      'risksNext90M': nextRisks, // Added this back
      'notificationContent': {
        'title': _currentRisk.score >= 0.7 ? 'Urgent Risk' : 'Pulse Active',
        'subtitle': _currentRisk.reasons.isNotEmpty
            ? _currentRisk.reasons.first
            : 'Monitoring your context…',
        'urgency': _currentRisk.score >= 0.7
            ? 'high'
            : (_currentRisk.score >= 0.4 ? 'medium' : 'low'),
      },
      'notificationDigest': {
        'highlight': highlight,
        'urgent': urgent,
        'important': important,
        'noiseCount': noiseCount,
      },
      'nextAction': _proposedCommAction,
    };

    notifyListeners();
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
      _processPulseEvent(data);
    } catch (e) {
      debugPrint('[Pulse] Error parsing message: $e');
    }

    notifyListeners();
  }

  void _processPulseEvent(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final timestampStr = data['timestamp'] as String?;
    final timestamp = timestampStr != null
        ? DateTime.parse(timestampStr)
        : DateTime.now();

    // Event capture for Timeline
    if (type == 'context.updated') {
      final cData = data['data'];
      if (cData != null) {
        _timelineEvents.insert(
          0,
          TimelineEvent(
            id: data['eventId'] ?? const Uuid().v4(),
            timestamp: timestamp,
            type: 'Context',
            agent: 'Context',
            text: 'Device state snapshot ingested.',
            data: cData,
          ),
        );
      }
    } else if (type == 'risk.updated') {
      final risks = data['data']?['risks'] as List<dynamic>? ?? [];
      if (risks.isNotEmpty) {
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

      debugPrint(
        '[Pulse AppState] Risk update received for user: ${data['userId']}',
      );
      final rData = data['data'];
      if (rData != null) {
        _currentRiskSnapshot = RiskSnapshot.fromJson(rData);
        _risksNext90Min = _currentRiskSnapshot!.risks.length;
        _activeRiskTypes = _currentRiskSnapshot!.risks
            .map(
              (r) => r.type == RiskType.responseDebt
                  ? "response_debt"
                  : r.type.name,
            )
            .toSet()
            .toList();

        debugPrint(
          '[Pulse AppState] Risk sync complete: types=$_activeRiskTypes, count=$_risksNext90Min',
        );

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

      _localRepo.saveRisk(
        timestamp.toIso8601String(),
        data['data']?['level'] ?? 'unknown',
        data,
      );
    } else if (type == 'COMM_ACTION_PROPOSED') {
      _proposedCommAction = data['data'];
      _timelineEvents.insert(
        0,
        TimelineEvent(
          id: data['eventId'] ?? const Uuid().v4(),
          timestamp: timestamp,
          type: 'Action',
          agent: 'CommPlanner',
          text: 'Message proposed: ${data['data']?['previewText']}',
          data: data['data'],
        ),
      );
    } else if (type == 'planner.suggested') {
      debugPrint('[Pulse AppState] Planner suggestion received');
      _lastPlannerDecision = data['data'];
      final chosen = data['data']?['chosen'];
      if (chosen != null) {
        _timelineEvents.insert(
          0,
          TimelineEvent(
            id: data['eventId'] ?? const Uuid().v4(),
            timestamp: timestamp,
            type: 'Action',
            agent: 'Planner',
            text: 'Suggested: ${chosen['title']}',
            data: chosen,
          ),
        );
      }
    } else if (type == 'guardian.decided') {
      _timelineEvents.insert(
        0,
        TimelineEvent(
          id: data['eventId'] ?? const Uuid().v4(),
          timestamp: timestamp,
          type: 'Outcome',
          agent: 'Guardian',
          text:
              'Approved: ${data['data']?['rationale'] ?? 'Security check passed'}',
          data: data['data'],
        ),
      );
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
            type: 'Outcome',
            agent: 'System',
            text: 'Intervention active: ${intv['headline']}',
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

        _localRepo.saveTimelineEvent(
          intvId,
          timestamp.toIso8601String(),
          type ?? 'unknown',
          data,
        );
      }
    } else if (type == 'pulse.snapshot') {
      // Dedup by version — ignore older or duplicate snapshots
      if (data['userId'] != null && data['userId'] != _userId) return;
      final incomingVersion = (data['version'] as num?)?.toInt() ?? 0;
      if (incomingVersion > _lastPulseSnapshotVersion) {
        final incoming = data['data'];
        if (incoming is Map<String, dynamic>) {
          _lastPulseSnapshotVersion = incomingVersion;
          _pulseSnapshot = incoming;
          debugPrint(
            '[Pulse] pulse.snapshot v$incomingVersion → state=${_pulseSnapshot["state"]}',
          );
          _updateNativeNotification();
        }
      } else {
        debugPrint(
          '[Pulse] pulse.snapshot v$incomingVersion ignored (stale, current v$_lastPulseSnapshotVersion)',
        );
      }
    } else if (type == 'futures.updated') {
      debugPrint('[Pulse AppState] Futures update received');
      _currentFutures = data['data'];
    } else if (type == 'heartbeat.tick') {
      if (data['userId'] != null && data['userId'] != _userId) return;
      debugPrint(
        '[Pulse AppState] Heartbeat tick: risksNext90Min=${data['data']?['risksNext90Min']}',
      );
      _lastHeartbeatTime = timestamp;
      final hData = data['data'];
      if (hData != null) {
        if (hData['risksNext90Min'] != null) {
          _risksNext90Min = (hData['risksNext90Min'] as num).toInt();
        }
        if (hData['score'] != null) {
          final newScore = (hData['score'] as num).toDouble();
          _currentRisk = RiskState(
            score: newScore,
            level: _parseRiskLevel(hData['state'] as String?),
            timestamp: timestamp,
            reasons: _currentRisk.reasons,
            history: _currentRisk.history,
          );
        }
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
    } else if (type == 'TWIN_UPDATED') {
      if (data['userId'] != null && data['userId'] != _userId) return;
      debugPrint('[Pulse AppState] Twin Graph update triggered');
      fetchTwinGraph();
    }

    notifyListeners();
    _syncPulseSnapshot();
    _updateNativeNotification();
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
        "id": const Uuid().v4(),
        "user_id": _userId,
        "device_id": _userId,
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
                  "location_text":
                      _deviceContext.upcomingEvents.first.locationText,
                  "location":
                      _deviceContext.upcomingEvents.first.latitude != null
                      ? {
                          "lat": _deviceContext.upcomingEvents.first.latitude,
                          "lon": _deviceContext.upcomingEvents.first.longitude,
                        }
                      : null,
                  "start_location":
                      _deviceContext.upcomingEvents.first.startLocation,
                  "organizer_contact":
                      _deviceContext.upcomingEvents.first.organizerContact,
                  "is_all_day": false,
                  "importance": "high",
                }
              : null,
          "upcoming_events": _deviceContext.upcomingEvents
              .map(
                (e) => {
                  "id":
                      "event_${e.title.hashCode}_${e.start.millisecondsSinceEpoch}",
                  "title": e.title,
                  "start_time": e.start.toUtc().toIso8601String(),
                  "end_time": e.end.toUtc().toIso8601String(),
                  "location_text": e.locationText,
                  "location": e.latitude != null
                      ? {"lat": e.latitude, "lon": e.longitude}
                      : null,
                  "start_location": e.startLocation,
                },
              )
              .toList(),
        },
        "battery": {
          "level": _deviceContext.battery.level / 100.0,
          "is_charging": _deviceContext.battery.isCharging,
          "power_saver_on": _deviceContext.battery.isInBatterySaveMode,
        },
        "notification_digest": _generateNotificationDigest(),
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
        headers: _authHeaders,
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

        _syncPulseSnapshot();
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

  Future<void> fetchFutures() async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse(
        'http://$host:8080/api/futures?userId=$_userId&deviceId=$_userId',
      );
      final response = await http.get(url, headers: _authHeaders);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentFutures = data['data'];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error fetching futures: $e');
    }
  }

  Future<void> fetchAppointmentEta() async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse(
        'http://$host:8080/api/routing/next-appointment-eta?userId=$_userId&deviceId=$_userId',
      );
      final response = await http.get(url, headers: _authHeaders);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _etaInfo = AppointmentEtaInfo.fromJson(data['data']);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error fetching appointment ETA: $e');
    }
  }

  Future<void> fetchTwinGraph() async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse(
        'http://$host:8080/api/twin/graph?userId=$_userId&deviceId=$_userId',
      );
      final response = await http.get(url, headers: _authHeaders);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _twinGraph = TwinGraph.fromJson(data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error fetching twin graph: $e');
    }
  }

  Future<void> fetchTwinSummary() async {
    _isTwinSummarizing = true;
    _twinSummary = null;
    notifyListeners();

    try {
      final host = _getBackendHost();
      final url = Uri.parse(
        'http://$host:8080/api/twin/summary?userId=$_userId&deviceId=$_userId',
      );
      final response = await http.get(url, headers: _authHeaders);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _twinSummary = data['data']['summary'];
      } else {
        _twinSummary = "Failed to generate summary. (Error: ${response.statusCode})";
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error fetching twin summary: $e');
      _twinSummary = "Connection error. Could not reach Pulse backend.";
    } finally {
      _isTwinSummarizing = false;
      notifyListeners();
    }
  }

  Future<void> triggerSelfReflection() async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/twin/reflect');
      final response = await http.post(
        url,
        headers: _authHeaders,
        body: json.encode({'userId': _userId}),
      );

      if (response.statusCode == 200) {
        debugPrint('[Pulse AppState] Self-reflection triggered successfully');
        await fetchTwinGraph();
        await fetchTwinSummary();
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error triggering self-reflection: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchGraphExplanation(String nodeId) async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/graph/explain/$nodeId');
      final response = await http.get(url, headers: _authHeaders);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error fetching graph explanation: $e');
    }
    return null;
  }

  Future<List<dynamic>> fetchSuggestedActions(
    String riskType, {
    required String nodeId,
  }) async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse(
        'http://$host:8080/api/planner/suggested-actions?riskType=$riskType&nodeId=$nodeId',
      );
      final response = await http.get(url, headers: _authHeaders);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      }
    } catch (e) {
      debugPrint('[Pulse AppState] Error fetching suggested actions: $e');
    }
    return [];
  }

  void setSimulatedLocation(double lat, double lon, String label) {
    _deviceContext = DeviceContext(
      battery: _deviceContext.battery,
      location: LocationInfo(latitude: lat, longitude: lon, status: label),
      upcomingEvents: _deviceContext.upcomingEvents,
      notifications: _deviceContext.notifications,
      timestamp: DateTime.now(),
    );
    notifyListeners();
    _sendContextSnapshot("manual_location_update");
  }

  void triggerManualSnapshot() {
    _sendContextSnapshot("manual_trigger");
  }

  /// Sends a one-tap action to the backend (POST /api/pulse/action).
  /// Also broadcasts `action.dispatched` back via WebSocket if connected.
  Future<void> dispatchPulseAction(Map<String, dynamic> action) async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/pulse/action');
      debugPrint(
        '[Pulse] Dispatching action: ${action['type']} id=${action['id']}',
      );
      final response = await http.post(
        url,
        headers: _authHeaders,
        body: jsonEncode({
          'userId': _userId,
          'deviceId': _userId,
          'action': action,
        }),
      );
      if (response.statusCode == 200) {
        debugPrint('[Pulse] Action acknowledged by backend.');
      } else {
        debugPrint('[Pulse] Action dispatch error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[Pulse] Action dispatch exception: $e');
    }
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

  Future<Map<String, dynamic>?> prepareCommAction(
    String actionId, {
    String? role,
  }) async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/comm/prepare');
      final response = await http.post(
        url,
        headers: _authHeaders,
        body: jsonEncode({
          'userId': _userId,
          'deviceId': _userId,
          'actionId': actionId,
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      }
    } catch (e) {
      debugPrint(
        '[Pulse AppState] prepareCommAction failed, falling back to local: $e',
      );
    }

    // Local fallback
    return _generateLocalCommAction(actionId, role: role);
  }

  Map<String, dynamic> _generateLocalCommAction(
    String actionId, {
    String? role,
  }) {
    final eventTitle = _etaInfo?.eventTitle ?? "the meeting";
    String text = "Running a bit late to $eventTitle. See you soon!";

    final aid = actionId.toUpperCase();
    if (aid.contains("BATTERY") || aid.contains("CHARGE")) {
      text = "Battery low, might be hard to reach for a bit.";
    }

    // Basic local "smart" variation based on role
    if (role == "Manager") {
      text = "Running late for $eventTitle. Will be there as soon as possible.";
    } else if (role == "Family") {
      text = "Hey! Running a bit behind for $eventTitle. See you in a bit! ❤️";
    }

    return {
      'channel': 'SMS',
      'text': text,
      'recipient': '123-456-7890',
      'actionId': actionId,
      'role': role ?? "General",
    };
  }

  Future<void> completeCommAction(String actionId) async {
    try {
      final host = _getBackendHost();
      final url = Uri.parse('http://$host:8080/api/comm/send');
      await http.post(
        url,
        headers: _authHeaders,
        body: jsonEncode({
          'userId': _userId,
          'deviceId': _userId,
          'actionId': actionId,
        }),
      );

      // Mark as completed
      _proposedCommAction = null;
      _acceptedActionIds.add(actionId);
      notifyListeners();
    } catch (e) {
      debugPrint('[Pulse AppState] completeCommAction failed: $e');
    }
  }

  Future<void> importData(String json) async {
    await _localRepo.importFromJson(json);
    await _initLocalData();
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

  void _updateNativeNotification() {
    final snap = _pulseSnapshot;
    final pulseState = snap['state'] as String? ?? 'NOMINAL';
    final content = snap['notificationContent'] as Map<String, dynamic>?;
    final digest = snap['notificationDigest'] as Map<String, dynamic>?;

    final title = content?['title'] as String? ?? 'Pulse active';
    final subtitle = content?['subtitle'] as String? ?? 'Monitoring…';
    final highlight = (content?['highlight'] as String?)?.isNotEmpty == true
        ? content!['highlight'] as String
        : digest?['highlight'] as String?;

    final body = highlight != null && highlight.isNotEmpty
        ? '$subtitle\n$highlight'
        : subtitle;

    NotificationService().showPulseNotification(
      title: title,
      body: body,
      state: pulseState,
    );

    _updateHomeScreenWidget();
  }

  void _updateHomeScreenWidget() {
    final snap = _pulseSnapshot;
    final score = (snap['topRiskScore'] as num?)?.toDouble() ?? 0.0;
    final state = snap['state'] as String? ?? 'NOMINAL';
    final nextRisks =
        (snap['risksNext90M'] as List<dynamic>?)
            ?.map((e) => (e as Map<String, dynamic>)['label'] as String)
            .toList() ??
        [];
    final digest = snap['notificationDigest'] as Map<String, dynamic>?;
    final urgent =
        (digest?['urgent'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final important =
        (digest?['important'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final allRisks = [...urgent, ...important, ...nextRisks];

    HomeWidget.saveWidgetData<String>('risk_score', score.toStringAsFixed(2));
    HomeWidget.saveWidgetData<String>('risk_label', state);
    HomeWidget.saveWidgetData<String>(
      'risk_1',
      allRisks.isNotEmpty ? allRisks[0] : "Monitoring...",
    );
    HomeWidget.saveWidgetData<String>(
      'risk_2',
      allRisks.length > 1 ? allRisks[1] : "",
    );
    HomeWidget.saveWidgetData<String>(
      'risk_3',
      allRisks.length > 2 ? allRisks[2] : "",
    );
    HomeWidget.saveWidgetData<String>('risk_count', "${allRisks.length}");

    HomeWidget.updateWidget(
      name: 'PulseWidgetProvider',
      androidName: 'PulseWidgetProvider',
    );
  }

  String _getBackendHost() {
    return '10.166.208.141';
  }

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'X-Device-Id': _userId,
    'X-User-Id': _userId,
  };

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}
