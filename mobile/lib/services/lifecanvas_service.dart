import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/groq_config.dart';
import '../config/backend_config.dart';
import '../models/lifecanvas_graph.dart';
import 'life_canvas_timeline_math.dart';
import 'lifecanvas_diary.dart';

class LifeCanvasLlmException implements Exception {
  final String message;
  LifeCanvasLlmException(this.message);
  @override
  String toString() => 'LifeCanvasLlmException: $message';
}

// ─── Central LifeCanvas API service ───────────────────────────────────────────
class LifeCanvasService {
  String get _base {
    const host = BackendConfig.host;
    if (host.startsWith('http://') || host.startsWith('https://')) {
      return '$host/api/lifecanvas';
    }
    if (host.contains(':')) {
      return 'http://$host/api/lifecanvas';
    }
    if (host.contains('192.168.') || host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2' || host.startsWith('10.')) {
      return kIsWeb ? 'http://127.0.0.1:8080/api/lifecanvas' : 'http://$host:8080/api/lifecanvas';
    } else {
      return 'https://$host/api/lifecanvas';
    }
  }
  static const String _groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  Future<String> _resolveGroqKey() async {
    const fromDefine = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    final stored = await lifecanvasDiary.getApiKey();
    if (stored.trim().isNotEmpty) return stored.trim();
    return GroqConfig.apiKey;
  }

  LifeCanvasGraph? _cachedGraph;

  // ── Graph ────────────────────────────────────────────────────────────────────
  Future<LifeCanvasGraph> fetchGraph(String userId, {String? dateStr}) async {
    final ds = dateStr ?? DateTime.now().toIso8601String().substring(0, 10);
    // Check if we have it stored locally for that date
    final stored = await lifecanvasDiary.getDailyGraph(ds);
    if (stored != null && stored.nodes.isNotEmpty) {
      final day = DateTime.tryParse('${ds}T12:00:00') ?? DateTime.now();
      _cachedGraph = _filterGraphForDay(stored, day);
      return _cachedGraph!;
    }

    try {
      final r = await http
          .get(Uri.parse('$_base/graph?userId=$userId'))
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
      debugPrint(
        '[LifeCanvasService] fetchGraph failed or timed out: $e. Returning high-fidelity mock galaxy.',
      );
    }

    final day = DateTime.tryParse('${ds}T12:00:00') ?? DateTime.now();
    final g = _mockGraph(forDay: day);
    _cachedGraph = g;
    await lifecanvasDiary.saveDailyGraph(ds, g);
    return g;
  }

  LifeCanvasGraph _filterGraphForDay(LifeCanvasGraph g, DateTime forDay) {
    if (!LifeCanvasTimelineMath.isViewingToday(forDay)) return g;
    final now = DateTime.now();
    final nodes = g.nodes.where((n) {
      if (n.type == 'THEME' || n.type == 'START') return true;
      final ts = n.timestamp ?? n.createdAt;
      return !ts.isAfter(now);
    }).toList();
    final ids = nodes.map((n) => n.id).toSet();
    final edges = g.edges
        .where((e) => ids.contains(e.sourceId) && ids.contains(e.targetId))
        .toList();
    return LifeCanvasGraph(nodes: nodes, edges: edges);
  }

  static bool _isTreeEvent(LifeCanvasNode n) =>
      n.type == 'LIFE_EVENT' ||
      n.type == 'EVENT' ||
      n.type == 'GOAL' ||
      n.type == 'HABIT' ||
      n.type == 'INSIGHT' ||
      n.type == 'MILESTONE';

  /// Fresh day: START marker + theme hubs only (no mock events after NOW).
  LifeCanvasGraph _emptyDayGraph({required DateTime forDay}) {
    final ds =
        '${forDay.year}-${forDay.month.toString().padLeft(2, '0')}-${forDay.day.toString().padLeft(2, '0')}';
    final shell = _themeShell(forDay);
    final start = LifeCanvasNode(
      id: 'root_$ds',
      label: ds,
      type: 'START',
      importance: 0.2,
      createdAt: forDay,
      themes: [],
      people: [],
    );
    return LifeCanvasGraph(nodes: [start, ...shell.nodes], edges: []);
  }

  LifeCanvasNode? _findThemeNode(LifeCanvasGraph g, String themeLabel) {
    final tl = themeLabel.toLowerCase().trim();
    LifeCanvasNode? best;
    for (final n in g.nodes) {
      if (n.type != 'THEME') continue;
      final nl = n.label.toLowerCase();
      if (nl == tl) return n;
      if (nl.contains(tl) || tl.contains(nl)) best = n;
    }
    if (best != null) return best;
    for (final n in g.nodes) {
      if (n.type == 'THEME') return n;
    }
    return null;
  }

  /// Merges [node] into the daily graph for [dateStr] and persists. Creates theme + temporal edges when possible.
  Future<void> addNodeToCache(LifeCanvasNode node, {String? dateStr}) async {
    final ds = dateStr ?? DateTime.now().toIso8601String().substring(0, 10);
    var g = await lifecanvasDiary.getDailyGraph(ds);
    if (g == null || g.nodes.isEmpty) {
      g = _themeShell(DateTime.tryParse('${ds}T12:00:00') ?? DateTime.now());
    }
    _cachedGraph = g;

    if (_cachedGraph!.nodes.any((n) => n.id == node.id)) return;
    _cachedGraph!.nodes.add(node);

    if (node.themes.isNotEmpty) {
      final themeNode = _findThemeNode(_cachedGraph!, node.themes.first);
      if (themeNode != null) {
        _cachedGraph!.edges.add(
          LifeCanvasEdge(
            id: 'edge_dyn_${DateTime.now().millisecondsSinceEpoch}',
            sourceId: themeNode.id,
            targetId: node.id,
            relation: 'thematic_relation',
            strength: 0.88,
          ),
        );
      }
    }

    final events = _cachedGraph!.nodes.where(_isTreeEvent).toList()..sort(
          (a, b) => (a.timestamp ?? a.createdAt).compareTo(
            b.timestamp ?? b.createdAt,
          ),
        );
    LifeCanvasNode? previous;
    for (final e in events) {
      if (e.id == node.id) break;
      previous = e;
    }
    if (previous != null && previous.id != node.id) {
      final exists = _cachedGraph!.edges.any(
        (ed) =>
            (ed.sourceId == previous!.id && ed.targetId == node.id) ||
            (ed.sourceId == node.id && ed.targetId == previous.id),
      );
      if (!exists) {
        _cachedGraph!.edges.add(
          LifeCanvasEdge(
            id: 'edge_temp_${DateTime.now().millisecondsSinceEpoch}',
            sourceId: previous.id,
            targetId: node.id,
            relation: 'temporal_sequence',
            strength: 0.62,
          ),
        );
      }
    }

    // Light semantic link: same primary theme as previous event
    if (previous != null &&
        previous.themes.isNotEmpty &&
        node.themes.isNotEmpty &&
        previous.themes.first.toLowerCase() ==
            node.themes.first.toLowerCase()) {
      final prevId = previous.id;
      final exists = _cachedGraph!.edges.any(
        (ed) =>
            ed.sourceId == prevId &&
            ed.targetId == node.id &&
            ed.relation == 'same_theme_chain',
      );
      if (!exists) {
        _cachedGraph!.edges.add(
          LifeCanvasEdge(
            id: 'edge_themechain_${DateTime.now().millisecondsSinceEpoch}',
            sourceId: previous.id,
            targetId: node.id,
            relation: 'same_theme_chain',
            strength: 0.45,
          ),
        );
      }
    }

    await lifecanvasDiary.saveDailyGraph(ds, _cachedGraph!);
  }

  LifeCanvasGraph _themeShell(DateTime at) {
    return LifeCanvasGraph(
      nodes: [
        LifeCanvasNode(
          id: 't_work',
          label: 'Work & Coding',
          type: 'THEME',
          importance: 0.9,
          createdAt: at,
          themes: [],
          people: [],
        ),
        LifeCanvasNode(
          id: 't_health',
          label: 'Health & Energy',
          type: 'THEME',
          importance: 0.8,
          createdAt: at,
          themes: [],
          people: [],
        ),
        LifeCanvasNode(
          id: 't_mind',
          label: 'Mindfulness',
          type: 'THEME',
          importance: 0.7,
          createdAt: at,
          themes: [],
          people: [],
        ),
        LifeCanvasNode(
          id: 't_social',
          label: 'Social Connections',
          type: 'THEME',
          importance: 0.8,
          createdAt: at,
          themes: [],
          people: [],
        ),
        LifeCanvasNode(
          id: 't_creative',
          label: 'Creative Pursuits',
          type: 'THEME',
          importance: 0.75,
          createdAt: at,
          themes: [],
          people: [],
        ),
        LifeCanvasNode(
          id: 't_goals',
          label: 'Future Goals',
          type: 'THEME',
          importance: 0.95,
          createdAt: at,
          themes: [],
          people: [],
        ),
      ],
      edges: [],
    );
  }

  LifeCanvasGraph _mockGraph({required DateTime forDay}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d0 = DateTime(forDay.year, forDay.month, forDay.day);
    final isViewingToday = d0 == today;
    final cutoff = isViewingToday
        ? now
        : DateTime(forDay.year, forDay.month, forDay.day, 23, 59, 59);

    final base = DateTime(forDay.year, forDay.month, forDay.day, 12, 0);
    final nodes = <LifeCanvasNode>[
      LifeCanvasNode(
        id: 't_work',
        label: 'Work & Coding',
        type: 'THEME',
        importance: 0.9,
        createdAt: base,
        themes: [],
        people: [],
      ),
      LifeCanvasNode(
        id: 't_health',
        label: 'Health & Energy',
        type: 'THEME',
        importance: 0.8,
        createdAt: base,
        themes: [],
        people: [],
      ),
      LifeCanvasNode(
        id: 't_mind',
        label: 'Mindfulness',
        type: 'THEME',
        importance: 0.7,
        createdAt: base,
        themes: [],
        people: [],
      ),
      LifeCanvasNode(
        id: 't_social',
        label: 'Social Connections',
        type: 'THEME',
        importance: 0.8,
        createdAt: base,
        themes: [],
        people: [],
      ),
      LifeCanvasNode(
        id: 't_creative',
        label: 'Creative Pursuits',
        type: 'THEME',
        importance: 0.75,
        createdAt: base,
        themes: [],
        people: [],
      ),
      LifeCanvasNode(
        id: 't_goals',
        label: 'Future Goals',
        type: 'THEME',
        importance: 0.95,
        createdAt: base,
        themes: [],
        people: [],
      ),

      LifeCanvasNode(
        id: 'e_code',
        label: 'Productive Flutter Development',
        type: 'LIFE_EVENT',
        emotion: 'excited',
        importance: 0.9,
        createdAt: base.subtract(const Duration(hours: 6)),
        timestamp: base.subtract(const Duration(hours: 6)),
        summary:
            'Successfully integrated native MethodChannels for UsageStats and refined the custom force-directed graph UI.',
        themes: ['Work & Coding'],
        people: [],
      ),
      LifeCanvasNode(
        id: 'e_run',
        label: 'Sunset Jog in Park',
        type: 'LIFE_EVENT',
        emotion: 'calm',
        importance: 0.6,
        createdAt: base.subtract(const Duration(hours: 4)),
        timestamp: base.subtract(const Duration(hours: 4)),
        summary:
            'Completed a quick 5k run to refresh the mind. Heart rate was steady, felt great.',
        themes: ['Health & Energy'],
        people: [],
      ),
      LifeCanvasNode(
        id: 'e_med',
        label: 'Deep Breathing Session',
        type: 'LIFE_EVENT',
        emotion: 'peaceful',
        importance: 0.5,
        createdAt: base.subtract(const Duration(hours: 2)),
        timestamp: base.subtract(const Duration(hours: 2)),
        summary:
            'Spent 15 minutes doing focused box-breathing to relieve mental fatigue.',
        themes: ['Mindfulness'],
        people: [],
      ),
      LifeCanvasNode(
        id: 'e_dinner',
        label: 'Dinner with Family',
        type: 'LIFE_EVENT',
        emotion: 'joy',
        importance: 0.7,
        createdAt: base.subtract(const Duration(minutes: 30)),
        timestamp: base.subtract(const Duration(minutes: 30)),
        summary:
            'Had dinner together and shared stories about recent milestones.',
        themes: ['Social Connections'],
        people: [],
      ),
      LifeCanvasNode(
        id: 'e_piano',
        label: 'Learned Beethoven Sonatina',
        type: 'LIFE_EVENT',
        emotion: 'excited',
        importance: 0.8,
        createdAt: base.subtract(const Duration(hours: 12)),
        timestamp: base.subtract(const Duration(hours: 12)),
        summary:
            'Mastered the tempo changes and first movement transition on the keyboard.',
        themes: ['Creative Pursuits'],
        people: [],
      ),
      LifeCanvasNode(
        id: 'e_refactor',
        label: 'Optimized Graph Physics Engine',
        type: 'LIFE_EVENT',
        emotion: 'calm',
        importance: 0.75,
        createdAt: base.subtract(const Duration(hours: 8)),
        timestamp: base.subtract(const Duration(hours: 8)),
        summary:
            'Adjusted gravity constants and tuned repulsion limits for organic spacing.',
        themes: ['Work & Coding'],
        people: [],
      ),
      LifeCanvasNode(
        id: 'e_goal',
        label: 'Launch Pulse App',
        type: 'LIFE_EVENT',
        emotion: 'joy',
        importance: 0.95,
        createdAt: base.subtract(const Duration(hours: 24)),
        timestamp: base.subtract(const Duration(hours: 24)),
        summary:
            'Establish robust personal life intelligence assistant for public release.',
        themes: ['Future Goals'],
        people: [],
      ),
    ];

    bool notFuture(LifeCanvasNode n) {
      if (n.type == 'THEME') return true;
      final ts = n.timestamp ?? n.createdAt;
      return !ts.isAfter(cutoff);
    }

    final kept = nodes.where(notFuture).toList();
    final keptIds = kept.map((n) => n.id).toSet();

    final edges =
        <LifeCanvasEdge>[
              LifeCanvasEdge(
                id: 'edge_1',
                sourceId: 't_work',
                targetId: 'e_code',
                relation: 'thematic_relation',
                strength: 0.9,
              ),
              LifeCanvasEdge(
                id: 'edge_2',
                sourceId: 't_health',
                targetId: 'e_run',
                relation: 'thematic_relation',
                strength: 0.8,
              ),
              LifeCanvasEdge(
                id: 'edge_3',
                sourceId: 't_mind',
                targetId: 'e_med',
                relation: 'thematic_relation',
                strength: 0.85,
              ),
              LifeCanvasEdge(
                id: 'edge_4',
                sourceId: 't_social',
                targetId: 'e_dinner',
                relation: 'thematic_relation',
                strength: 0.9,
              ),
              LifeCanvasEdge(
                id: 'edge_5',
                sourceId: 't_creative',
                targetId: 'e_piano',
                relation: 'thematic_relation',
                strength: 0.8,
              ),
              LifeCanvasEdge(
                id: 'edge_6',
                sourceId: 't_work',
                targetId: 'e_refactor',
                relation: 'thematic_relation',
                strength: 0.75,
              ),
              LifeCanvasEdge(
                id: 'edge_7',
                sourceId: 't_goals',
                targetId: 'e_goal',
                relation: 'thematic_relation',
                strength: 0.95,
              ),
            ]
            .where(
              (e) =>
                  keptIds.contains(e.sourceId) && keptIds.contains(e.targetId),
            )
            .toList();

    return LifeCanvasGraph(nodes: kept, edges: edges);
  }

  // ── Ingest ───────────────────────────────────────────────────────────────────
  Future<bool> ingest(String userId, String text) async {
    try {
      final r = await http
          .post(
            Uri.parse('$_base/ingest'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'audioTranscript': text,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(
            const Duration(seconds: 4),
          ); // Shorter timeout for fluid fallback
      final j = jsonDecode(r.body);
      return j['ok'] == true;
    } catch (e) {
      debugPrint('[LifeCanvasService] ingest failed or offline: $e');
      return false;
    }
  }

  Future<LifeCanvasNode> parseIngestedLogDirectly(String text) async {
    final prompt =
        '''You are a cognitive life graph parsing AI. Parse the log entry into a structured graph node.
ENTRY: "$text"

Output ONLY valid JSON matching this schema:
{"label":"Concise Action/Event Label","type":"GOAL|EVENT|HABIT|INSIGHT","emotion":"excited|joy|calm|peaceful|tired|stressed","importance":0.8,"theme":"Work & Coding|Health & Energy|Mindfulness|Social Connections|Creative Pursuits|Future Goals","summary":"1-sentence summary of the action"}

Rules:
- Match theme strictly to one of the 6 themes listed.
- Keep importance between 0.1 and 1.0.
- Do not include markdown code block formatting in your output.''';

    final raw = await _callGroq(prompt);
    final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
    final m = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
    if (m == null) {
      throw LifeCanvasLlmException('Groq ingest response was not valid JSON.');
    }
    final j = jsonDecode(m.group(0)!);
    final now = DateTime.now();
      return LifeCanvasNode(
        id: 'e_custom_${DateTime.now().millisecondsSinceEpoch}',
        label: j['label'] ?? 'Custom Event',
        type: j['type'] ?? 'EVENT',
      importance: (j['importance'] as num? ?? 0.6).toDouble(),
      emotion: j['emotion'] ?? 'calm',
      summary: j['summary'] ?? text,
      createdAt: now,
      timestamp: now,
      themes: [j['theme'] ?? 'Work & Coding'],
      people: [],
    );
  }

  // ── Ask (Q&A with full life context; map-reduce when graph is large) ─────────
  Future<String> ask({
    required String query,
    required LifeCanvasGraph graph,
    required String diaryMd,
    required String recentLogs,
    required List<AppUsageStat> usageStats,
  }) async {
    final usageCtx = usageStats
        .take(8)
        .map((u) => '${u.appName}(${u.totalMinutes}min)')
        .join(', ');

    String nodeCtx;
    if (graph.nodes.length > 24) {
      final chunks = <String>[];
      const chunk = 22;
      for (var i = 0; i < graph.nodes.length; i += chunk) {
        final slice = graph.nodes
            .skip(i)
            .take(chunk)
            .map((n) => '[${n.type}] "${n.label}": ${n.summary ?? ""}')
            .join('\n');
        final sumPrompt =
            '''Summarize this LifeCanvas graph slice into 6 bullet points (facts + emotions). No preamble.
SLICE:\n$slice''';
        final s = await _callGroq(sumPrompt);
        chunks.add(s);
      }
      final mergePrompt =
          '''Merge these bullet summaries into one compact paragraph (max 120 words) preserving themes and tensions.
${chunks.join('\n---\n')}''';
      nodeCtx = await _callGroq(mergePrompt);
    } else {
      nodeCtx = graph.nodes
          .map((n) => '[${n.type}] "${n.label}": ${n.summary ?? ""}')
          .join('\n');
    }

    final prompt =
        '''You are LifeCanvas AI, a personal life intelligence assistant.
Answer concisely (2-5 sentences) using context below. Speak in second person.

CURRENT TIME: ${DateTime.now().toString()}
LIFE GRAPH (possibly summarized):\n$nodeCtx
DIARY NOTES: ${diaryMd.length > 500 ? diaryMd.substring(0, 500) : diaryMd}
RECENT LOGS: ${recentLogs.length > 300 ? recentLogs.substring(0, 300) : recentLogs}
SCREEN TIME TODAY: $usageCtx

QUESTION: $query''';

    return await _callGroq(prompt);
  }

  // ── Predict (phantom future events) ──────────────────────────────────────────
  Future<List<PredictedEvent>> predict({
    required LifeCanvasGraph graph,
    required String diaryMd,
    required List<AppUsageStat> usageStats,
  }) async {
    final now = DateTime.now();
    final nowH = now.hour + now.minute / 60.0;
    final nodeCtx = graph.nodes
        .take(15)
        .map((n) => '${n.label}(${n.type})')
        .join(', ');
    final usageCtx = usageStats
        .take(6)
        .map((u) => '${u.appName}(${u.totalMinutes}min)')
        .join(', ');

    final prompt =
        '''You are a life prediction AI. Predict the NEXT 4-6 likely events for today.
Current time: ${now.hour}:${now.minute.toString().padLeft(2, '0')} (${nowH.toStringAsFixed(2)}h into day)
Life nodes: $nodeCtx
Screen time: $usageCtx
Notes: ${diaryMd.length > 200 ? diaryMd.substring(0, 200) : diaryMd}

Output ONLY valid JSON:
{"predictions":[{"name":"Short concrete label","hoursFromNow":1.5,"durationHours":0.5,"type":"HABIT","color":"#hex","ganttApp":"Chrome","theme":"Work & Coding|Health & Energy|Mindfulness|Social Connections|Creative Pursuits|Future Goals"}]}
Rules: hoursFromNow > 0 and < 12. type = GOAL|EVENT|HABIT|INSIGHT. ganttApp must be one of: Screen,Messages,Chrome,Instagram,YouTube,WhatsApp,Spotify (or omit). theme must be one of the six listed.''';

    final raw = await _callGroq(prompt);
    final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
    final m = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
    if (m == null) {
      throw LifeCanvasLlmException('Groq predict response was not valid JSON.');
    }
    final j = jsonDecode(m.group(0)!);
    final preds = (j['predictions'] as List?) ?? [];
    final list = preds
        .map((p) => PredictedEvent.fromJson(p as Map<String, dynamic>, nowH))
        .toList();
    if (list.isEmpty) {
      throw LifeCanvasLlmException('Groq returned no predictions.');
    }
    return list;
  }

  // ── Brainstorm → MindMap ──────────────────────────────────────────────────────
  Future<List<MindNodeUpdate>> brainstormToMindMap({
    required List<String> items,
    required List<MindNode> existingNodes,
  }) async {
    final existingCtx = existingNodes.map((n) => n.name).join(', ');
    final prompt =
        '''Organise this list into a Mind Map knowledge graph.
LIST: ${items.join(', ')}
EXISTING NODES: $existingCtx

Output ONLY valid JSON:
{"updates":[{"id":"new_id","name":"Item","parentId":"existing_or_new_category","importance":35}]}''';

    final raw = await _callGroq(prompt);
    final m = RegExp(
      r'\{[\s\S]*\}',
    ).firstMatch(raw.replaceAll(RegExp(r'```json|```'), '').trim());
    if (m == null) {
      throw LifeCanvasLlmException('Groq mind-map response was not valid JSON.');
    }
    final j = jsonDecode(m.group(0)!);
    return ((j['updates'] as List?) ?? [])
        .map((u) => MindNodeUpdate.fromJson(u))
        .toList();
  }

  // ── Groq helper (no silent fallback) ─────────────────────────────────────────
  Future<String> _callGroq(String prompt) async {
    final apiKey = await _resolveGroqKey();
    if (apiKey.isEmpty) {
      throw LifeCanvasLlmException('Groq API key is not configured.');
    }

    final r = await http
        .post(
          Uri.parse(_groqUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (r.statusCode == 200) {
      final j = jsonDecode(r.body);
      final content = j['choices']?[0]?['message']?['content'] as String?;
      if (content != null && content.trim().isNotEmpty) return content;
      throw LifeCanvasLlmException('Groq returned an empty response.');
    }

    debugPrint('[LifeCanvasService] Groq HTTP ${r.statusCode}: ${r.body}');
    throw LifeCanvasLlmException('Groq API error (${r.statusCode}).');
  }
}

// ─── Supporting data models ────────────────────────────────────────────────────
class AppUsageHourSegment {
  final int hour;
  final double minutes;
  AppUsageHourSegment({required this.hour, required this.minutes});
  factory AppUsageHourSegment.fromJson(Map<String, dynamic> j) =>
      AppUsageHourSegment(
        hour: (j['hour'] as num?)?.toInt() ?? 0,
        minutes: (j['minutes'] as num?)?.toDouble() ?? 0,
      );
}

class AppUsageStat {
  final String appName;
  final int totalMinutes;
  final List<AppUsageHourSegment> hourlySegments;

  AppUsageStat({
    required this.appName,
    required this.totalMinutes,
    this.hourlySegments = const [],
  });
}

class PredictedEvent {
  final String name;
  final String type;
  final String color;
  final double hoursFromNow;
  final double durationHours;
  final String? appName;
  final double futureHour;

  /// One of the six LifeCanvas themes — used for translucent theme rail in UI.
  final String theme;

  PredictedEvent({
    required this.name,
    required this.type,
    required this.color,
    required this.hoursFromNow,
    required this.durationHours,
    this.appName,
    required this.futureHour,
    this.theme = 'Mindfulness',
  });

  factory PredictedEvent.fromJson(Map<String, dynamic> j, double nowH) {
    final hfn = (j['hoursFromNow'] as num? ?? 1).toDouble();
    return PredictedEvent(
      name: (j['name'] as String?)?.trim().isNotEmpty == true
          ? j['name'] as String
          : 'Upcoming block',
      type: j['type'] ?? 'EVENT',
      color: j['color'] ?? '#BF5AF2',
      hoursFromNow: hfn,
      durationHours: (j['durationHours'] as num? ?? 0.5).toDouble(),
      appName: (j['ganttApp'] ?? j['appName']) as String?,
      futureHour: nowH + hfn,
      theme: j['theme'] as String? ?? 'Work & Coding',
    );
  }
}

class MindNode {
  final String id;
  final String name;
  final String type; // EVENT | CATEGORY | HOLDER
  String? parentId;
  double x, y; // mutable for physics simulation

  MindNode({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.x = 0,
    this.y = 0,
  });
}

class MindEdge {
  final String sourceId;
  final String targetId;
  final bool directed;
  MindEdge({
    required this.sourceId,
    required this.targetId,
    this.directed = false,
  });
}

class MindNodeUpdate {
  final String id;
  final String name;
  final String? parentId;
  final int importance;
  MindNodeUpdate({
    required this.id,
    required this.name,
    this.parentId,
    required this.importance,
  });
  factory MindNodeUpdate.fromJson(Map<String, dynamic> j) => MindNodeUpdate(
    id: j['id'] ?? 'node_${DateTime.now().millisecondsSinceEpoch}',
    name: j['name'] ?? '',
    parentId: j['parentId'] as String?,
    importance: (j['importance'] as num? ?? 35).toInt(),
  );
}

final lifecanvasService = LifeCanvasService();
