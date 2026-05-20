import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/lifecanvas_graph.dart';
import 'lifecanvas_diary.dart';

// ─── Central LifeCanvas API service ───────────────────────────────────────────
class LifeCanvasService {
  static const String _base = kIsWeb ? 'http://127.0.0.1:8080/api/lifecanvas' : 'http://10.0.2.2:8080/api/lifecanvas';
  static const String _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _groqKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String _model = 'llama-3.3-70b-versatile';

  LifeCanvasGraph? _cachedGraph;

  // ── Graph ────────────────────────────────────────────────────────────────────
  Future<LifeCanvasGraph> fetchGraph(String userId, {String? dateStr}) async {
    final ds = dateStr ?? DateTime.now().toIso8601String().substring(0, 10);
    // Check if we have it stored locally for that date
    final stored = await lifecanvasDiary.getDailyGraph(ds);
    if (stored != null) {
      _cachedGraph = stored;
      return stored;
    }

    try {
      final r = await http.get(Uri.parse('$_base/graph?userId=$userId'))
          .timeout(const Duration(seconds: 4));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (j['ok'] == true) {
          final g = LifeCanvasGraph.fromJson(j['data']);
          if (g.nodes.isNotEmpty) {
            _cachedGraph = g;
            await lifecanvasDiary.saveDailyGraph(ds, g);
            return g;
          }
        }
      }
    } catch (e) {
      debugPrint('[LifeCanvasService] fetchGraph failed or timed out: $e. Returning high-fidelity mock galaxy.');
    }
    
    final g = _mockGraph();
    _cachedGraph = g;
    await lifecanvasDiary.saveDailyGraph(ds, g);
    return g;
  }

  void addNodeToCache(LifeCanvasNode node, {String? dateStr}) {
    if (_cachedGraph == null) {
      _cachedGraph = _mockGraph();
    }
    // Prevent duplicates
    if (_cachedGraph!.nodes.any((n) => n.id == node.id)) return;
    _cachedGraph!.nodes.add(node);

    // Build connections/edges amongst events in life tree based on context
    if (node.themes.isNotEmpty) {
      final themeLabel = node.themes.first;
      final themeNode = _cachedGraph!.nodes.firstWhere(
        (n) => n.label.toLowerCase() == themeLabel.toLowerCase() || n.id.toLowerCase() == themeLabel.toLowerCase(),
        orElse: () => _cachedGraph!.nodes.firstWhere((n) => n.type == 'THEME', orElse: () => _cachedGraph!.nodes.first),
      );
      _cachedGraph!.edges.add(LifeCanvasEdge(
        id: 'edge_dyn_${DateTime.now().millisecondsSinceEpoch}',
        sourceId: themeNode.id,
        targetId: node.id,
        relation: 'thematic_relation',
        strength: 0.85,
      ));
    }

    // Persist immediately!
    final ds = dateStr ?? DateTime.now().toIso8601String().substring(0, 10);
    lifecanvasDiary.saveDailyGraph(ds, _cachedGraph!);
  }

  LifeCanvasGraph _mockGraph() {
    final now = DateTime.now();
    final nodes = <LifeCanvasNode>[
      LifeCanvasNode(id: 't_work', label: 'Work & Coding', type: 'THEME', importance: 0.9, createdAt: now, themes: [], people: []),
      LifeCanvasNode(id: 't_health', label: 'Health & Energy', type: 'THEME', importance: 0.8, createdAt: now, themes: [], people: []),
      LifeCanvasNode(id: 't_mind', label: 'Mindfulness', type: 'THEME', importance: 0.7, createdAt: now, themes: [], people: []),
      LifeCanvasNode(id: 't_social', label: 'Social Connections', type: 'THEME', importance: 0.8, createdAt: now, themes: [], people: []),
      LifeCanvasNode(id: 't_creative', label: 'Creative Pursuits', type: 'THEME', importance: 0.75, createdAt: now, themes: [], people: []),
      LifeCanvasNode(id: 't_goals', label: 'Future Goals', type: 'THEME', importance: 0.95, createdAt: now, themes: [], people: []),
      
      LifeCanvasNode(id: 'e_code', label: 'Productive Flutter Development', type: 'LIFE_EVENT', emotion: 'excited', importance: 0.9, createdAt: now.subtract(const Duration(hours: 6)), timestamp: now.subtract(const Duration(hours: 6)), summary: 'Successfully integrated native MethodChannels for UsageStats and refined the custom force-directed graph UI.', themes: ['Work & Coding'], people: []),
      LifeCanvasNode(id: 'e_run', label: 'Sunset Jog in Park', type: 'LIFE_EVENT', emotion: 'calm', importance: 0.6, createdAt: now.subtract(const Duration(hours: 4)), timestamp: now.subtract(const Duration(hours: 4)), summary: 'Completed a quick 5k run to refresh the mind. Heart rate was steady, felt great.', themes: ['Health & Energy'], people: []),
      LifeCanvasNode(id: 'e_med', label: 'Deep Breathing Session', type: 'LIFE_EVENT', emotion: 'peaceful', importance: 0.5, createdAt: now.subtract(const Duration(hours: 2)), timestamp: now.subtract(const Duration(hours: 2)), summary: 'Spent 15 minutes doing focused box-breathing to relieve mental fatigue.', themes: ['Mindfulness'], people: []),
      LifeCanvasNode(id: 'e_dinner', label: 'Dinner with Family', type: 'LIFE_EVENT', emotion: 'joy', importance: 0.7, createdAt: now.subtract(const Duration(minutes: 30)), timestamp: now.subtract(const Duration(minutes: 30)), summary: 'Had dinner together and shared stories about recent milestones.', themes: ['Social Connections'], people: []),
      LifeCanvasNode(id: 'e_piano', label: 'Learned Beethoven Sonatina', type: 'LIFE_EVENT', emotion: 'excited', importance: 0.8, createdAt: now.subtract(const Duration(hours: 12)), timestamp: now.subtract(const Duration(hours: 12)), summary: 'Mastered the tempo changes and first movement transition on the keyboard.', themes: ['Creative Pursuits'], people: []),
      LifeCanvasNode(id: 'e_refactor', label: 'Optimized Graph Physics Engine', type: 'LIFE_EVENT', emotion: 'calm', importance: 0.75, createdAt: now.subtract(const Duration(hours: 8)), timestamp: now.subtract(const Duration(hours: 8)), summary: 'Adjusted gravity constants and tuned repulsion limits for organic spacing.', themes: ['Work & Coding'], people: []),
      LifeCanvasNode(id: 'e_goal', label: 'Launch Pulse App', type: 'LIFE_EVENT', emotion: 'joy', importance: 0.95, createdAt: now.subtract(const Duration(hours: 24)), timestamp: now.subtract(const Duration(hours: 24)), summary: 'Establish robust personal life intelligence assistant for public release.', themes: ['Future Goals'], people: []),
    ];

    final edges = <LifeCanvasEdge>[
      LifeCanvasEdge(id: 'edge_1', sourceId: 't_work', targetId: 'e_code', relation: 'thematic_relation', strength: 0.9),
      LifeCanvasEdge(id: 'edge_2', sourceId: 't_health', targetId: 'e_run', relation: 'thematic_relation', strength: 0.8),
      LifeCanvasEdge(id: 'edge_3', sourceId: 't_mind', targetId: 'e_med', relation: 'thematic_relation', strength: 0.85),
      LifeCanvasEdge(id: 'edge_4', sourceId: 't_social', targetId: 'e_dinner', relation: 'thematic_relation', strength: 0.9),
      LifeCanvasEdge(id: 'edge_5', sourceId: 't_creative', targetId: 'e_piano', relation: 'thematic_relation', strength: 0.8),
      LifeCanvasEdge(id: 'edge_6', sourceId: 't_work', targetId: 'e_refactor', relation: 'thematic_relation', strength: 0.75),
      LifeCanvasEdge(id: 'edge_7', sourceId: 't_goals', targetId: 'e_goal', relation: 'thematic_relation', strength: 0.95),
    ];

    return LifeCanvasGraph(nodes: nodes, edges: edges);
  }

  // ── Ingest ───────────────────────────────────────────────────────────────────
  Future<bool> ingest(String userId, String text) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/ingest'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'audioTranscript': text, 'timestamp': DateTime.now().toIso8601String()}),
      ).timeout(const Duration(seconds: 4)); // Shorter timeout for fluid fallback
      final j = jsonDecode(r.body);
      return j['ok'] == true;
    } catch (e) {
      debugPrint('[LifeCanvasService] ingest failed or offline: $e');
      return false;
    }
  }

  Future<LifeCanvasNode?> parseIngestedLogDirectly(String text) async {
    final prompt = '''You are a cognitive life graph parsing AI. Parse the log entry into a structured graph node.
ENTRY: "$text"

Output ONLY valid JSON matching this schema:
{"label":"Concise Action/Event Label","type":"LIFE_EVENT","emotion":"excited|joy|calm|peaceful|tired|stressed","importance":0.8,"theme":"Work & Coding|Health & Energy|Mindfulness|Social Connections|Creative Pursuits|Future Goals","summary":"1-sentence summary of the action"}

Rules:
- Match theme strictly to one of the 6 themes listed.
- Keep importance between 0.1 and 1.0.
- Do not include markdown code block formatting in your output.''';
    
    try {
      final raw = await _callGroq(prompt);
      if (raw == null) return null;
      final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (m == null) return null;
      final j = jsonDecode(m.group(0)!);
      final now = DateTime.now();
      return LifeCanvasNode(
        id: 'e_custom_${DateTime.now().millisecondsSinceEpoch}',
        label: j['label'] ?? 'Custom Event',
        type: 'LIFE_EVENT',
        importance: (j['importance'] as num? ?? 0.6).toDouble(),
        emotion: j['emotion'] ?? 'calm',
        summary: j['summary'] ?? text,
        createdAt: now,
        timestamp: now,
        themes: [j['theme'] ?? 'Work & Coding'],
        people: [],
      );
    } catch (e) {
      debugPrint('[LifeCanvasService] parseIngestedLogDirectly failed: $e');
      return null;
    }
  }

  LifeCanvasNode parseIngestedLogRuleBased(String text) {
    final now = DateTime.now();
    String label = text;
    if (text.length > 30) label = text.substring(0, 27) + '...';
    
    String theme = 'Work & Coding';
    if (text.toLowerCase().contains('run') || text.toLowerCase().contains('gym') || text.toLowerCase().contains('walk') || text.toLowerCase().contains('eat') || text.toLowerCase().contains('health')) {
      theme = 'Health & Energy';
    } else if (text.toLowerCase().contains('meditat') || text.toLowerCase().contains('breathe') || text.toLowerCase().contains('sleep') || text.toLowerCase().contains('mind')) {
      theme = 'Mindfulness';
    } else if (text.toLowerCase().contains('family') || text.toLowerCase().contains('friend') || text.toLowerCase().contains('dinner') || text.toLowerCase().contains('chat')) {
      theme = 'Social Connections';
    } else if (text.toLowerCase().contains('piano') || text.toLowerCase().contains('music') || text.toLowerCase().contains('draw') || text.toLowerCase().contains('creative')) {
      theme = 'Creative Pursuits';
    } else if (text.toLowerCase().contains('goal') || text.toLowerCase().contains('achieve') || text.toLowerCase().contains('launch')) {
      theme = 'Future Goals';
    }
    
    return LifeCanvasNode(
      id: 'e_custom_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      type: 'LIFE_EVENT',
      importance: 0.7,
      emotion: 'calm',
      summary: text,
      createdAt: now,
      timestamp: now,
      themes: [theme],
      people: [],
    );
  }

  // ── Ask (Q&A with full life context) ─────────────────────────────────────────
  Future<String> ask({
    required String query,
    required LifeCanvasGraph graph,
    required String diaryMd,
    required String recentLogs,
    required List<AppUsageStat> usageStats,
  }) async {
    final nodeCtx = graph.nodes.take(30)
        .map((n) => '[${n.type}] "${n.label}": ${n.summary ?? ""}')
        .join('\n');
    final usageCtx = usageStats.take(8)
        .map((u) => '${u.appName}(${u.totalMinutes}min)')
        .join(', ');

    final prompt = '''You are LifeCanvas AI, a personal life intelligence assistant.
Answer concisely (2-5 sentences) using context below. Speak in second person.

CURRENT TIME: ${DateTime.now().toString()}
LIFE GRAPH NODES:\n$nodeCtx
DIARY NOTES: ${diaryMd.length > 500 ? diaryMd.substring(0, 500) : diaryMd}
RECENT LOGS: ${recentLogs.length > 300 ? recentLogs.substring(0, 300) : recentLogs}
SCREEN TIME TODAY: $usageCtx

QUESTION: $query''';

    return await _callGroq(prompt) ?? 'Could not get a response. Check your connection.';
  }

  // ── Predict (phantom future events) ──────────────────────────────────────────
  Future<List<PredictedEvent>> predict({
    required LifeCanvasGraph graph,
    required String diaryMd,
    required List<AppUsageStat> usageStats,
  }) async {
    final now = DateTime.now();
    final nowH = now.hour + now.minute / 60.0;
    final nodeCtx = graph.nodes.take(15).map((n) => '${n.label}(${n.type})').join(', ');
    final usageCtx = usageStats.take(6).map((u) => '${u.appName}(${u.totalMinutes}min)').join(', ');

    final prompt = '''You are a life prediction AI. Predict the NEXT 4-6 likely events for today.
Current time: ${now.hour}:${now.minute.toString().padLeft(2, '0')} (${nowH.toStringAsFixed(2)}h into day)
Life nodes: $nodeCtx
Screen time: $usageCtx
Notes: ${diaryMd.length > 200 ? diaryMd.substring(0, 200) : diaryMd}

Output ONLY valid JSON:
{"predictions":[{"name":"...","hoursFromNow":1.5,"durationHours":0.5,"type":"HABIT","color":"#hex","appName":"Chrome"}]}
Rules: hoursFromNow > 0 and < 12. type = GOAL|EVENT|HABIT|INSIGHT. appName optional.''';

    try {
      final raw = await _callGroq(prompt);
      if (raw == null) return [];
      final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (m == null) return [];
      final j = jsonDecode(m.group(0)!);
      final preds = (j['predictions'] as List?) ?? [];
      return preds.map((p) => PredictedEvent.fromJson(p, nowH)).toList();
    } catch (e) {
      debugPrint('[LifeCanvasService] predict failed: $e');
      return [];
    }
  }

  // ── Brainstorm → MindMap ──────────────────────────────────────────────────────
  Future<List<MindNodeUpdate>> brainstormToMindMap({
    required List<String> items,
    required List<MindNode> existingNodes,
  }) async {
    final existingCtx = existingNodes.map((n) => n.name).join(', ');
    final prompt = '''Organise this list into a Mind Map knowledge graph.
LIST: ${items.join(', ')}
EXISTING NODES: $existingCtx

Output ONLY valid JSON:
{"updates":[{"id":"new_id","name":"Item","parentId":"existing_or_new_category","importance":35}]}''';

    try {
      final raw = await _callGroq(prompt);
      if (raw == null) return [];
      final m = RegExp(r'\{[\s\S]*\}').firstMatch(raw.replaceAll(RegExp(r'```json|```'), '').trim());
      if (m == null) return [];
      final j = jsonDecode(m.group(0)!);
      return ((j['updates'] as List?) ?? []).map((u) => MindNodeUpdate.fromJson(u)).toList();
    } catch (e) {
      debugPrint('[LifeCanvasService] brainstorm failed: $e');
      return [];
    }
  }

  // ── Groq helper ───────────────────────────────────────────────────────────────
  Future<String?> _callGroq(String prompt) async {
    try {
      final r = await http.post(
        Uri.parse(_groqUrl),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_groqKey'},
        body: jsonEncode({'model': _model, 'messages': [{'role': 'user', 'content': prompt}]}),
      ).timeout(const Duration(seconds: 25));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        return j['choices']?[0]?['message']?['content'] as String?;
      }
    } catch (e) { debugPrint('[LifeCanvasService] Groq call failed: $e'); }
    return null;
  }
}

// ─── Supporting data models ────────────────────────────────────────────────────
class AppUsageStat {
  final String appName;
  final int totalMinutes;
  AppUsageStat({required this.appName, required this.totalMinutes});
}

class PredictedEvent {
  final String name;
  final String type;
  final String color;
  final double hoursFromNow;
  final double durationHours;
  final String? appName;
  final double futureHour;

  PredictedEvent({
    required this.name, required this.type, required this.color,
    required this.hoursFromNow, required this.durationHours,
    this.appName, required this.futureHour,
  });

  factory PredictedEvent.fromJson(Map<String, dynamic> j, double nowH) {
    final hfn = (j['hoursFromNow'] as num? ?? 1).toDouble();
    return PredictedEvent(
      name: j['name'] ?? 'Event',
      type: j['type'] ?? 'EVENT',
      color: j['color'] ?? '#BF5AF2',
      hoursFromNow: hfn,
      durationHours: (j['durationHours'] as num? ?? 0.5).toDouble(),
      appName: j['appName'] as String?,
      futureHour: nowH + hfn,
    );
  }
}

class MindNode {
  final String id;
  final String name;
  final String type; // EVENT | CATEGORY | HOLDER
  String? parentId;
  double x, y; // mutable for physics simulation

  MindNode({required this.id, required this.name, required this.type, this.parentId, this.x = 0, this.y = 0});
}

class MindEdge {
  final String sourceId;
  final String targetId;
  final bool directed;
  MindEdge({required this.sourceId, required this.targetId, this.directed = false});
}

class MindNodeUpdate {
  final String id;
  final String name;
  final String? parentId;
  final int importance;
  MindNodeUpdate({required this.id, required this.name, this.parentId, required this.importance});
  factory MindNodeUpdate.fromJson(Map<String, dynamic> j) => MindNodeUpdate(
    id: j['id'] ?? 'node_${DateTime.now().millisecondsSinceEpoch}',
    name: j['name'] ?? '',
    parentId: j['parentId'] as String?,
    importance: (j['importance'] as num? ?? 35).toInt(),
  );
}

final lifecanvasService = LifeCanvasService();
