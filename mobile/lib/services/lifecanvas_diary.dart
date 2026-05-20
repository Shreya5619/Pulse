import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lifecanvas_graph.dart';

// ─── Local diary + log persistence (SharedPreferences) ────────────────────────
class LifeCanvasDiary {
  static const _diaryKey = 'lc_diary_md';
  static const _logsKey = 'lc_recent_logs';

  // ── Daily Graph Persistence ───────────────────────────────────────────────
  Future<LifeCanvasGraph?> getDailyGraph(String dateStr) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('lc_graph_$dateStr');
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw);
      return LifeCanvasGraph.fromJson(j);
    } catch (e) {
      debugPrint('[LifeCanvasDiary] failed to parse daily graph for $dateStr: $e');
      return null;
    }
  }

  Future<void> saveDailyGraph(String dateStr, LifeCanvasGraph graph) async {
    final p = await SharedPreferences.getInstance();
    final raw = jsonEncode(graph.toJson());
    await p.setString('lc_graph_$dateStr', raw);
  }

  // ── Diary (lifecanvas.md) ──────────────────────────────────────────────────
  Future<String> getDiary() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_diaryKey) ?? '# LifeCanvas Diary\n\n*Your life story unfolds here.*\n';
  }

  Future<void> appendDiaryEntry(String date, String summary) async {
    final p = await SharedPreferences.getInstance();
    final current = p.getString(_diaryKey) ?? '# LifeCanvas Diary\n\n';
    final entry = '\n## $date\n$summary\n';
    await p.setString(_diaryKey, current + entry);
  }

  Future<void> saveDiary(String content) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_diaryKey, content);
  }

  // ── Recent Logs (recentHistory.md) ────────────────────────────────────────
  Future<String> getLogs() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_logsKey) ?? '';
  }

  Future<void> appendLog(String text) async {
    final p = await SharedPreferences.getInstance();
    final current = p.getString(_logsKey) ?? '';
    final ts = DateTime.now().toLocal().toString().substring(0, 16);
    await p.setString(_logsKey, '$current\n[$ts] $text');
  }

  // ── Mind Twin state ────────────────────────────────────────────────────────
  static const _mindKey = 'lc_mind_nodes';
  static const _mindEdgeKey = 'lc_mind_edges';

  Future<List<Map<String, dynamic>>> getMindNodes() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_mindKey);
    if (raw == null) return _defaultMindNodes();
    try {
      return (List<dynamic>.from(
        (raw.isNotEmpty ? raw.split('||') : []).map((s) {
          final parts = s.split('::');
          if (parts.length < 3) return null;
          return {'id': parts[0], 'name': parts[1], 'type': parts[2], 'parentId': parts.length > 3 ? parts[3] : null};
        }).where((e) => e != null),
      )).cast<Map<String, dynamic>>();
    } catch (_) { return _defaultMindNodes(); }
  }

  Future<void> saveMindNodes(List<Map<String, dynamic>> nodes) async {
    final p = await SharedPreferences.getInstance();
    final encoded = nodes.map((n) => '${n['id']}::${n['name']}::${n['type']}::${n['parentId'] ?? ''}').join('||');
    await p.setString(_mindKey, encoded);
  }

  Future<List<Map<String, dynamic>>> getMindEdges() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_mindEdgeKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return raw.split('||').map((s) {
        final parts = s.split('::');
        if (parts.length < 2) return null;
        return {'sourceId': parts[0], 'targetId': parts[1], 'directed': parts.length > 2 && parts[2] == 'true'};
      }).where((e) => e != null).cast<Map<String, dynamic>>().toList();
    } catch (_) { return []; }
  }

  Future<void> saveMindEdges(List<Map<String, dynamic>> edges) async {
    final p = await SharedPreferences.getInstance();
    final encoded = edges.map((e) => '${e['sourceId']}::${e['targetId']}::${e['directed']}').join('||');
    await p.setString(_mindEdgeKey, encoded);
  }

  List<Map<String, dynamic>> _defaultMindNodes() => [
    {'id': 'cat_identity', 'name': 'Identity', 'type': 'CATEGORY', 'parentId': null},
    {'id': 'cat_goals', 'name': 'Goals', 'type': 'CATEGORY', 'parentId': null},
    {'id': 'cat_habits', 'name': 'Habits', 'type': 'CATEGORY', 'parentId': null},
    {'id': 'cat_people', 'name': 'People', 'type': 'CATEGORY', 'parentId': null},
    {'id': 'cat_interests', 'name': 'Interests', 'type': 'CATEGORY', 'parentId': null},
  ];
}

final lifecanvasDiary = LifeCanvasDiary();
