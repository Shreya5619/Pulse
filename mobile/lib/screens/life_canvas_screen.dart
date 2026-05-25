import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../models/lifecanvas_graph.dart';
import '../services/lifecanvas_service.dart';
import '../widgets/life_canvas_reasoning_panel.dart';
import '../widgets/life_canvas_sidebar.dart';
import '../widgets/life_canvas_gantt.dart';
import '../widgets/life_canvas_timeline_painter.dart';
import '../services/life_canvas_timeline_math.dart';
import 'mind_twin_screen.dart';

enum ViewMode { galaxy, river, timeline }
enum InputMode { ingest, ask, predict }

class LifeCanvasScreen extends StatefulWidget {
  const LifeCanvasScreen({super.key});
  @override
  State<LifeCanvasScreen> createState() => _LifeCanvasScreenState();
}

class _LifeCanvasScreenState extends State<LifeCanvasScreen> with TickerProviderStateMixin {
  ViewMode _viewMode = ViewMode.timeline;
  InputMode _inputMode = InputMode.ingest;
  DateTime _timelineBaseDate = DateTime.now();

  final TextEditingController _journal = TextEditingController();
  final FocusNode _journalFocus = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  
  final TransformationController _viewCtrl = TransformationController();

  late AnimationController _pulse;
  Map<String, Offset>? _galaxyPosCache;
  String? _galaxyPosSig;

  bool _isProcessing = false;
  final List<AgentStep> _steps = [];
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
    
    _viewCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().fetchLifeCanvasGraph();
      _resetView();
    });
  }

  Offset _getRotatedPosition(Offset basePos, double pulseValue) {
    if (_viewMode != ViewMode.galaxy) return basePos;
    final r = basePos.distance;
    if (r < 20) return basePos; // Don't rotate center/root
    final baseAngle = math.atan2(basePos.dy, basePos.dx);
    final orbitSpeed = 40.0 / math.max(math.sqrt(r), 1.0);
    final currentAngle = baseAngle + pulseValue * 2 * math.pi * orbitSpeed * 0.015;
    return Offset(r * math.cos(currentAngle), r * math.sin(currentAngle));
  }

  void _resetView() {
    final size = MediaQuery.of(context).size;
    final screenW = size.width;
    final screenH = size.height;
    final nowH = LifeCanvasTimelineMath.nowHourOnDate(_timelineBaseDate);
    final graphX = LifeCanvasTimelineMath.graphXFromHour(nowH);
    final childX = LifeCanvasTimelineMath.canvasAnchorX + graphX;
    final tx = screenW * 0.45 - childX;
    final ty = screenH * 0.42 - LifeCanvasTimelineMath.canvasAnchorY;
    setState(() {
      _viewCtrl.value = Matrix4.identity()..translate(tx, ty);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _journal.dispose(); _journalFocus.dispose();
    _viewCtrl.dispose();
    super.dispose();
  }

  /// Life Tree layout — matches web chronoX = 100 + hour * 200.
  Map<String, Offset> _timelinePos(List<LifeCanvasNode> nodes) {
    final pos = <String, Offset>{};
    final events = nodes
        .where((n) =>
            n.type != 'THEME' &&
            n.type != 'START' &&
            n.type != 'MARK' &&
            n.type != 'MIN_MARK')
        .toList()
      ..sort((a, b) =>
          (a.timestamp ?? a.createdAt).compareTo(b.timestamp ?? b.createdAt));

    for (var i = 0; i < events.length; i++) {
      final n = events[i];
      final dt = n.timestamp ?? n.createdAt;
      pos[n.id] = LifeCanvasTimelineMath.eventPosition(
        timestamp: dt,
        baseDate: _timelineBaseDate,
        laneIndex: i,
        nodeType: n.type,
        importance: n.importance,
      );
    }

    final startId =
        'root_${_timelineBaseDate.toIso8601String().substring(0, 10)}';
    if (nodes.any((n) => n.id == startId)) {
      pos[startId] = const Offset(
        LifeCanvasTimelineMath.timeOriginX,
        300,
      );
    }
    return pos;
  }

  List<LifeCanvasNode> _visibleNodes(LifeCanvasGraph graph) {
    if (_viewMode != ViewMode.timeline) return graph.nodes;
    return graph.nodes.where((n) {
      if (n.type == 'THEME') return false;
      if (n.type == 'START') return true;
      if (n.type != 'LIFE_EVENT' &&
          n.type != 'GOAL' &&
          n.type != 'HABIT' &&
          n.type != 'INSIGHT' &&
          n.type != 'MILESTONE') {
        return false;
      }
      final ts = n.timestamp ?? n.createdAt;
      return !LifeCanvasTimelineMath.isEventAfterNow(ts, _timelineBaseDate);
    }).toList();
  }

  List<LifeCanvasEdge> _visibleEdges(
    LifeCanvasGraph graph,
    Set<String> visibleIds,
  ) {
    return graph.edges
        .where((e) =>
            visibleIds.contains(e.sourceId) && visibleIds.contains(e.targetId))
        .toList();
  }

  List<PredictedEvent> _visiblePredictions(List<PredictedEvent> preds) {
    if (_viewMode != ViewMode.timeline) return [];
    if (!LifeCanvasTimelineMath.isViewingToday(_timelineBaseDate)) {
      return [];
    }
    final nowH = LifeCanvasTimelineMath.nowHourOnDate(_timelineBaseDate);
    return preds.where((p) => p.futureHour > nowH).toList();
  }

  // ─── Actions ────────────────────────────────────────────────────────────────
  void _submitInput(String text) {
    if (_inputMode == InputMode.ingest) _ingest(text);
    else if (_inputMode == InputMode.ask) _ask(text);
    else _predict(); // Ignore text for predict
  }

  Future<void> _ingest(String text) async {
    if (text.trim().isEmpty) return;
    _journalFocus.unfocus();
    _startProcessing('Observing entry...');

    final appState = context.read<AppState>();
    _addStep(1, 'thinking', 'Observing Raw Input', '"${text.substring(0, math.min(55, text.length))}${text.length > 55 ? '...' : ''}"');
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() => _statusText = 'Retrieving context...');
    _addStep(2, 'command', 'Context Retrieval', 'Loading recent event nodes and active themes from memory graph...');
    await Future.delayed(const Duration(milliseconds: 700));

    setState(() => _statusText = 'Reasoning...');
    _addStep(3, 'cypher', 'Reasoning (Groq Llama-3.3)', 'Sending dual-graph extraction prompt to cognitive agent.',
        cmd: 'POST /api/lifecanvas/ingest\nModel: llama-3.3-70b-versatile');
    
    final ok = await appState.ingestLifeCanvasLog(
      text.trim(),
      dateStr: _timelineBaseDate.toIso8601String().substring(0, 10),
    );

    setState(() => _statusText = 'Applying mutations...');
    _addStep(4, 'result', 'Proposing Graph Mutations', ok ? 'Validated node + theme edges ready to commit.' : 'Groq extraction failed — check API key and network.');
    await Future.delayed(const Duration(milliseconds: 500));

    _addStep(5, ok ? 'final' : 'error', ok ? 'Galaxy Updated' : 'Partial Update', ok ? 'Memory node persisted. Galaxy is evolving.' : 'JSON store fallback was used.');
    _stopProcessing(ok ? null : 'Failed to ingest properly.');
    if (ok) {
      appState.fetchLifeCanvasGraph(
        dateStr: _timelineBaseDate.toIso8601String().substring(0, 10),
      );
    }
  }

  Future<void> _ask(String text) async {
    if (text.trim().isEmpty) return;
    _journalFocus.unfocus();
    _startProcessing('Synthesizing life context...');

    final appState = context.read<AppState>();
    _addStep(1, 'thinking', 'Query Analyzed', '"$text"');
    await Future.delayed(const Duration(milliseconds: 400));
    
    _addStep(2, 'command', 'Context Synthesis', 'Merging Graph, Twin, and Gantt usage data.');
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() => _statusText = 'Consulting Agent...');
    _addStep(3, 'cypher', 'Groq Inference', 'Prompting with combined state.', cmd: 'POST /ask');

    final answer = await appState.askLifeCanvas(text.trim());

    _addStep(4, 'final', 'Response Generated', answer);
    _stopProcessing(null, keepText: true); // Keep input around for context
    
    // Show answer modal
    if (mounted) {
      showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1123),
        title: Text('LifeCanvas AI', style: GoogleFonts.outfit(color: const Color(0xFF00E5FF))),
        content: Text(answer, style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, height: 1.4)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.white54)))],
      ));
    }
  }

  Future<void> _predict() async {
    _journalFocus.unfocus();
    _startProcessing('Simulating futures...');
    final appState = context.read<AppState>();
    
    _addStep(1, 'thinking', 'Predictive Simulation', 'Analyzing today\'s trajectory and historical patterns.');
    await Future.delayed(const Duration(milliseconds: 600));
    
    _addStep(2, 'command', 'Gantt Extrapolation', 'Projecting App Usage stats into future hours.');
    await Future.delayed(const Duration(milliseconds: 400));
    
    setState(() => _statusText = 'Generating phantoms...');
    _addStep(3, 'cypher', 'Temporal Inference', 'LLM calculating probable future events.', cmd: 'POST /predict');

    await appState.predictLifeCanvasTimeline();

    _addStep(4, 'final', 'Timeline Updated', 'Phantom nodes added to Timeline and Gantt chart.');
    
    setState(() {
      _viewMode = ViewMode.timeline; // Auto-switch to timeline to see predictions
      _isProcessing = false;
      _statusText = '';
    });
  }

  void _startProcessing(String text) {
    setState(() {
      _isProcessing = true;
      _steps.clear();
      _statusText = text;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final w = MediaQuery.of(context).size.width;
      if (w < 760) _scaffoldKey.currentState?.openEndDrawer();
    });
  }
  void _addStep(int id, String type, String title, String detail, {String? cmd}) => setState(() => _steps.add(AgentStep(id: id, type: type, title: title, detail: detail, cmd: cmd)));
  void _stopProcessing(String? error, {bool keepText = false}) => setState(() { _isProcessing = false; _statusText = ''; if (!keepText) _journal.clear(); if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error))); });

  void _setDate(DateTime d) {
    setState(() {
      _timelineBaseDate = d;
      _viewMode = ViewMode.timeline;
    });
    final ds = d.toIso8601String().substring(0, 10);
    context.read<AppState>().fetchLifeCanvasGraph(dateStr: ds);
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final graph = state.lifeCanvasGraph;
    final isLoading = state.isLifeCanvasLoading;

    final visibleNodes = _visibleNodes(graph);
    final visibleIds = visibleNodes.map((n) => n.id).toSet();
    final visibleEdges = _visibleEdges(graph, visibleIds);
    final visiblePreds = _visiblePredictions(state.predictions);

    Map<String, Offset> positions;
    if (_viewMode == ViewMode.galaxy) {
      final sig = '${graph.nodes.length}_${graph.edges.length}_${graph.nodes.map((n) => n.id).join('|')}';
      if (_galaxyPosCache == null || _galaxyPosSig != sig) {
        _galaxyPosCache = _computeGalaxyPositions(graph);
        _galaxyPosSig = sig;
      }
      positions = _galaxyPosCache!;
    } else if (_viewMode == ViewMode.river) {
      positions = _riverPos(graph.nodes);
    } else {
      positions = _timelinePos(graph.nodes);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF070814),
      drawer: LifeCanvasSidebar(
        graph: graph,
        isGalaxyView: _viewMode == ViewMode.galaxy,
        onViewToggle: (v) { setState(() => _viewMode = v ? ViewMode.galaxy : ViewMode.river); Navigator.pop(context); },
        onRefresh: () {
          context.read<AppState>().fetchLifeCanvasGraph(
            dateStr: _timelineBaseDate.toIso8601String().substring(0, 10),
          );
          Navigator.pop(context);
        },
      ),
      endDrawer: Drawer(
        width: 320,
        backgroundColor: const Color(0xFF0F1123),
        child: SafeArea(
          child: LifeCanvasReasoningPanel(
            steps: _steps,
            isActive: _isProcessing,
            statusText: _statusText,
            expandVertically: true,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bc) {
            final mainColumn = Column(
              children: [
            // ── Top Bar ───────────────────────────────────────────────────────
            Container(
              height: 56, padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))), color: const Color(0xFF070814)),
              child: Row(children: [
                IconButton(icon: const Icon(LucideIcons.menu, size: 19, color: Colors.white60), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
                const SizedBox(width: 8),
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('LifeCanvas', style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  Text(_viewMode.name.toUpperCase(), style: GoogleFonts.outfit(color: const Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
                ]),
                const Spacer(),
                IconButton(icon: const Icon(LucideIcons.calendar, size: 17, color: Colors.white54), onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: _timelineBaseDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d != null) _setDate(d);
                }),
                IconButton(
                  icon: const Icon(LucideIcons.terminal, size: 18, color: Color(0xFF64D2FF)),
                  tooltip: 'Agent Trace',
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                ),
                IconButton(icon: const Icon(LucideIcons.brain, size: 18, color: Color(0xFFBF5AF2)), tooltip: 'Mind Twin', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MindTwinScreen()))),
              ]),
            ),

            // ── View Toggles ──────────────────────────────────────────────────
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _viewTab('Life Tree', ViewMode.timeline), const SizedBox(width: 8),
                _viewTab('Galaxy', ViewMode.galaxy), const SizedBox(width: 8),
                _viewTab('River', ViewMode.river),
                IconButton(icon: const Icon(LucideIcons.zoomIn, size: 16, color: Colors.white54), onPressed: () => setState(() => _viewCtrl.value = _viewCtrl.value.clone()..scale(1.3))),
                IconButton(icon: const Icon(LucideIcons.zoomOut, size: 16, color: Colors.white54), onPressed: () => setState(() => _viewCtrl.value = _viewCtrl.value.clone()..scale(1 / 1.3))),
                IconButton(icon: const Icon(LucideIcons.refreshCw, size: 14, color: Colors.white54), tooltip: 'Reset View', onPressed: _resetView),
                IconButton(
                  icon: const Icon(LucideIcons.rotateCw, size: 14, color: Color(0xFF00E5FF)),
                  tooltip: 'Refresh Data',
                  onPressed: () {
                    context.read<AppState>().fetchLifeCanvasGraph(
                      dateStr: _timelineBaseDate.toIso8601String().substring(0, 10),
                    );
                  },
                ),
              ]),
            ),

            // ── Canvas Area (Life Tree + Gantt overlay like web prototype) ─────
            Expanded(
              child: LayoutBuilder(
                builder: (context, canvasConstraints) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, __) =>
                              CustomPaint(painter: _StarfieldPainter(_pulse.value)),
                        ),
                      ),
                      if (isLoading)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: Color(0xFF00E5FF),
                                strokeWidth: 1.5,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Loading cognitive universe...',
                                style: GoogleFonts.outfit(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        InteractiveViewer(
                          transformationController: _viewCtrl,
                          minScale: 0.001,
                          maxScale: 10.0,
                          constrained: false,
                          boundaryMargin: const EdgeInsets.all(4000),
                          child: AnimatedBuilder(
                            animation: _pulse,
                            builder: (context, _) {
                              final rotatedPositions = <String, Offset>{};
                              positions.forEach((id, basePos) {
                                rotatedPositions[id] = _getRotatedPosition(basePos, _pulse.value);
                              });
                              return SizedBox(
                                width: 2000,
                                height: 1200,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _EdgePainter(
                                          visibleEdges,
                                          visibleNodes,
                                          rotatedPositions,
                                          _viewMode == ViewMode.galaxy,
                                        ),
                                      ),
                                    ),
                                    ...visibleNodes.map((node) {
                                      final p = rotatedPositions[node.id];
                                      if (p == null) {
                                        return const SizedBox.shrink();
                                      }
                                      final half = _nodeHalfSize(node);
                                      final isStart = node.type == 'START';
                                      return Positioned(
                                        left: LifeCanvasTimelineMath.canvasAnchorX +
                                            p.dx -
                                            half,
                                        top: LifeCanvasTimelineMath.canvasAnchorY +
                                            p.dy -
                                            half,
                                        child: GestureDetector(
                                          onTap: () => _showDetail(node),
                                          child: isStart
                                              ? _StartNode(label: node.label)
                                              : _NodeWidget(
                                                  node: node,
                                                  color: _nodeColor(node),
                                                  pulse: math.sin(_pulse.value * 2 * math.pi).abs(),
                                                  isPhantom: false,
                                                ),
                                        ),
                                      );
                                    }),
                                    if (_viewMode == ViewMode.timeline)
                                      ...visiblePreds.map((pred) {
                                        final graphX =
                                            LifeCanvasTimelineMath.graphXFromHour(
                                          pred.futureHour,
                                        );
                                        final graphY = 200.0 +
                                            (pred.name.hashCode % 120 - 60);
                                        final tint =
                                            _themeColorFromLabel(pred.theme);
                                        return Positioned(
                                          left: LifeCanvasTimelineMath
                                                  .canvasAnchorX +
                                              graphX -
                                              6,
                                          top: LifeCanvasTimelineMath
                                                  .canvasAnchorY +
                                              graphY -
                                              28,
                                          child: _PhantomNode(
                                            pred: pred,
                                            themeTint: tint,
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        if (_viewMode == ViewMode.timeline) ...[
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF070814)
                                    .withValues(alpha: 0.88),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                              ),
                              child: CustomPaint(
                                painter: LifeCanvasTimelinePainter(
                                  transform: _viewCtrl.value,
                                  baseDate: _timelineBaseDate,
                                  viewportWidth: canvasConstraints.maxWidth,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 40,
                            left: 0,
                            right: 0,
                            height: LifeCanvasGantt.stripHeight,
                            child: IgnorePointer(
                              child: LifeCanvasGantt(
                                stats: state.usageStats,
                                predictions: visiblePreds,
                                transform: _viewCtrl.value,
                                baseDate: _timelineBaseDate,
                              ),
                            ),
                          ),
                          LifeCanvasNowBar(
                            transform: _viewCtrl.value,
                            baseDate: _timelineBaseDate,
                          ),
                          const Positioned(
                            left: 8,
                            bottom: 8,
                            child: _EmotionLegend(compact: true),
                          ),
                        ] else
                          const Positioned(
                            left: 8,
                            bottom: 12,
                            child: _EmotionLegend(compact: true),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),

            // ── Input Dock ────────────────────────────────────────────────────
            _InputDock(
              controller: _journal,
              focusNode: _journalFocus,
              isProcessing: _isProcessing,
              currentMode: _inputMode,
              onModeChange: (m) => setState(() => _inputMode = m),
              onSubmit: () => _submitInput(_journal.text),
            ),
          ],
        );

        if (bc.maxWidth >= 760) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: mainColumn),
              SizedBox(
                width: 300,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF070814),
                    border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: LifeCanvasReasoningPanel(
                    steps: _steps,
                    isActive: _isProcessing,
                    statusText: _statusText,
                    expandVertically: true,
                  ),
                ),
              ),
            ],
          );
        }
        return mainColumn;
          },
        ),
      ),
    );
  }

  Widget _viewTab(String label, ViewMode mode) => GestureDetector(
    onTap: () => setState(() => _viewMode = mode),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _viewMode == mode ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: GoogleFonts.outfit(color: _viewMode == mode ? Colors.white : Colors.white38, fontSize: 12, fontWeight: _viewMode == mode ? FontWeight.w600 : FontWeight.w400)),
    ),
  );

  // Layout math — gravity spiral (static; no orbit spin)
  Map<String, Offset> _computeGalaxyPositions(LifeCanvasGraph graph) {
    final nodes = graph.nodes;
    final pos = <String, Offset>{};
    final themes = nodes.where((n) => n.type == 'THEME').toList();
    final events = nodes
        .where((n) => LifeCanvasTimelineMath.isTreeEventType(n.type))
        .toList();

    for (int i = 0; i < themes.length; i++) {
      final angle = i * 2 * math.pi / math.max(themes.length, 1);
      pos[themes[i].id] = Offset(130 * math.cos(angle), 130 * math.sin(angle));
    }

    const arms = 3;
    for (int i = 0; i < events.length; i++) {
      final ev = events[i];
      final arm = i % arms;
      final armAngle = arm * (2 * math.pi / arms);
      final t = (i ~/ arms) * 0.55 + 0.35;
      final r = 175.0 + 42.0 * t;
      final theta = armAngle + t * 1.15;
      pos[ev.id] = Offset(r * math.cos(theta), r * math.sin(theta));
    }

    const iterations = 48;
    const repulsion = 4200.0;
    const springK = 0.014;
    const springLen = 95.0;
    const gravity = 0.012;
    final velocities = <String, Offset>{};
    final ids = pos.keys.toList();
    for (final id in ids) {
      velocities[id] = Offset.zero;
    }

    for (var step = 0; step < iterations; step++) {
      final forces = <String, Offset>{};
      for (final id in ids) {
        forces[id] = Offset.zero;
      }

      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final a = ids[i], b = ids[j];
          final pa = pos[a]!, pb = pos[b]!;
          var dx = pa.dx - pb.dx;
          var dy = pa.dy - pb.dy;
          var dist = math.sqrt(dx * dx + dy * dy);
          if (dist < 1) dist = 1;
          final force = repulsion / (dist * dist);
          final fx = (dx / dist) * force;
          final fy = (dy / dist) * force;
          forces[a] = forces[a]! + Offset(fx, fy);
          forces[b] = forces[b]! - Offset(fx, fy);
        }
      }

      for (final e in graph.edges) {
        if (!pos.containsKey(e.sourceId) || !pos.containsKey(e.targetId)) continue;
        final pa = pos[e.sourceId]!, pb = pos[e.targetId]!;
        var dx = pb.dx - pa.dx;
        var dy = pb.dy - pa.dy;
        var dist = math.sqrt(dx * dx + dy * dy);
        if (dist < 1) dist = 1;
        final d = dist - springLen;
        final fx = (dx / dist) * d * springK * e.strength;
        final fy = (dy / dist) * d * springK * e.strength;
        forces[e.sourceId] = forces[e.sourceId]! + Offset(fx, fy);
        forces[e.targetId] = forces[e.targetId]! - Offset(fx, fy);
      }

      for (final id in ids) {
        final p = pos[id]!;
        forces[id] = forces[id]! + Offset(-p.dx * gravity, -p.dy * gravity);
      }

      for (final id in ids) {
        var vel = velocities[id]! + forces[id]! * 0.85;
        final speed = vel.distance;
        if (speed > 6) vel = vel / speed * 6;
        velocities[id] = vel;
        if (speed > 0.04) {
          pos[id] = pos[id]! + vel;
        }
      }
    }

    // Aggregate connected event clusters toward shared theme hubs
    for (final theme in themes) {
      final hub = pos[theme.id];
      if (hub == null) continue;
      final linked = graph.edges
          .where((e) => e.sourceId == theme.id || e.targetId == theme.id)
          .map((e) => e.sourceId == theme.id ? e.targetId : e.sourceId)
          .where((id) => events.any((ev) => ev.id == id))
          .toList();
      if (linked.length < 2) continue;
      var cx = 0.0, cy = 0.0;
      for (final id in linked) {
        final p = pos[id];
        if (p != null) { cx += p.dx; cy += p.dy; }
      }
      cx /= linked.length;
      cy /= linked.length;
      final pull = Offset((hub.dx - cx) * 0.12, (hub.dy - cy) * 0.12);
      for (final id in linked) {
        pos[id] = pos[id]! + pull;
      }
    }

    return pos;
  }

  Map<String, Offset> _riverPos(List<LifeCanvasNode> nodes) {
    final pos = <String, Offset>{};
    final events = nodes.where((n) => n.type == 'LIFE_EVENT').toList()
      ..sort((a, b) => (a.timestamp ?? a.createdAt).compareTo(b.timestamp ?? b.createdAt));
    final startX = -((events.length - 1) * 240.0) / 2;
    for (int i = 0; i < events.length; i++) {
      final x = startX + i * 240.0;
      final y = 130.0 * math.sin(i * 0.9);
      pos[events[i].id] = Offset(x, y);
    }
    return pos;
  }

  Color _themeColorFromLabel(String theme) {
    final t = theme.toLowerCase();
    if (t.contains('work') || t.contains('coding')) return const Color(0xFF00E5FF);
    if (t.contains('health') || t.contains('energy')) return const Color(0xFF4EE2C9);
    if (t.contains('mind')) return const Color(0xFFBF5AF2);
    if (t.contains('social')) return const Color(0xFFFFB300);
    if (t.contains('creative')) return const Color(0xFFE040FB);
    if (t.contains('goal') || t.contains('future')) return const Color(0xFF0A84FF);
    return const Color(0xFF64D2FF);
  }

  double _nodeHalfSize(LifeCanvasNode node) {
    if (node.type == 'THEME') return (48.0 + 20.0 * node.importance) / 2;
    return (28.0 + 30.0 * node.importance) / 2;
  }

  Color _nodeColor(LifeCanvasNode node) {
    switch (node.type) {
      case 'GOAL':
        return const Color(0xFFBF5AF2);
      case 'MILESTONE':
        return const Color(0xFF64D2FF);
      case 'INSIGHT':
        return const Color(0xFF64D2FF);
      default:
        return _emotionColor(node.emotion);
    }
  }

  Color _emotionColor(String? e) {
    switch (e?.toLowerCase()) {
      case 'excited': case 'joy': return const Color(0xFFFFB300);
      case 'calm': case 'peaceful': return const Color(0xFF4EE2C9);
      case 'anxious': case 'stressed': return const Color(0xFFFF5252);
      case 'sad': return const Color(0xFF5C6BC0);
      case 'overwhelmed': return const Color(0xFFE040FB);
      default: return const Color(0xFF00E5FF);
    }
  }

  void _showDetail(LifeCanvasNode node) {
    final c = _emotionColor(node.emotion);
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (_) => Container(
      padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF0F1123), borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), border: Border.all(color: c.withValues(alpha: 0.2))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(node.label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        if (node.summary != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(node.summary!, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, height: 1.5))),
      ]),
    ));
  }
}

// ─── Input Dock with Mode Picker ──────────────────────────────────────────────
class _InputDock extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isProcessing;
  final InputMode currentMode;
  final Function(InputMode) onModeChange;
  final VoidCallback onSubmit;

  const _InputDock({required this.controller, required this.focusNode, required this.isProcessing, required this.currentMode, required this.onModeChange, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    String hint = 'Reflect on a memory...';
    Color themeColor = const Color(0xFF00E5FF);
    if (currentMode == InputMode.ask) { hint = 'Ask LifeCanvas anything...'; themeColor = const Color(0xFFFFB300); }
    else if (currentMode == InputMode.predict) { hint = 'Hit predict to simulate future...'; themeColor = const Color(0xFFBF5AF2); }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(color: const Color(0xFF07091A), border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Mode dropdown
        PopupMenuButton<InputMode>(
          color: const Color(0xFF1E1E2E),
          onSelected: onModeChange,
          itemBuilder: (_) => [
            _item(InputMode.ingest, 'Ingest', LucideIcons.penTool, const Color(0xFF00E5FF)),
            _item(InputMode.ask, 'Ask AI', LucideIcons.messageSquare, const Color(0xFFFFB300)),
            _item(InputMode.predict, 'Predict', LucideIcons.sparkles, const Color(0xFFBF5AF2)),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            margin: const EdgeInsets.only(right: 8, bottom: 2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [Text(currentMode.name.toUpperCase(), style: GoogleFonts.outfit(color: themeColor, fontSize: 10, fontWeight: FontWeight.w700)), const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16)]),
          ),
        ),
        // Text field
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 100),
            decoration: BoxDecoration(color: const Color(0xFF111328), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: TextField(
              controller: controller, focusNode: focusNode, maxLines: null, enabled: !isProcessing && currentMode != InputMode.predict,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 14)),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Submit
        GestureDetector(
          onTap: isProcessing ? null : onSubmit,
          child: Container(
            width: 44, height: 44, margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: isProcessing ? null : LinearGradient(colors: [themeColor, themeColor.withValues(alpha: 0.6)]), color: isProcessing ? Colors.white12 : null),
            child: isProcessing ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))) : Icon(currentMode == InputMode.predict ? LucideIcons.wand2 : LucideIcons.send, color: Colors.white, size: 17),
          ),
        ),
      ]),
    );
  }

  PopupMenuItem<InputMode> _item(InputMode m, String l, IconData i, Color c) => PopupMenuItem(value: m, child: Row(children: [Icon(i, color: c, size: 16), const SizedBox(width: 8), Text(l, style: TextStyle(color: c, fontSize: 14))]));
}

// Painters & Nodes (simplified for brevity)
class _StarfieldPainter extends CustomPainter {
  final double pulse; _StarfieldPainter(this.pulse);
  @override void paint(Canvas canvas, Size size) { final r=math.Random(42); for(int i=0;i<90;i++) canvas.drawCircle(Offset(r.nextDouble()*size.width, r.nextDouble()*size.height), (r.nextDouble()*1.5)*(0.4+0.6*math.sin(pulse*math.pi*2+i)), Paint()..color=Colors.white.withValues(alpha: r.nextDouble()*0.5)); }
  @override bool shouldRepaint(_StarfieldPainter o) => o.pulse != pulse;
}
class _EdgePainter extends CustomPainter {
  final List<LifeCanvasEdge> e;
  final List<LifeCanvasNode> n;
  final Map<String, Offset> p;
  final bool galaxyMode;
  _EdgePainter(this.e, this.n, this.p, this.galaxyMode);
  @override
  void paint(Canvas canvas, Size size) {
    final pt = Paint()..style = PaintingStyle.stroke;
    for (var ed in e) {
      final s = p[ed.sourceId], t = p[ed.targetId];
      if (s == null || t == null) continue;
      final alpha = galaxyMode ? 0.22 * ed.strength : 0.15 * ed.strength;
      pt
        ..color = const Color(0xFF00E5FF).withValues(alpha: alpha)
        ..strokeWidth = 1.0 + 1.8 * ed.strength;
      canvas.drawLine(
        Offset(
          LifeCanvasTimelineMath.canvasAnchorX + s.dx,
          LifeCanvasTimelineMath.canvasAnchorY + s.dy,
        ),
        Offset(
          LifeCanvasTimelineMath.canvasAnchorX + t.dx,
          LifeCanvasTimelineMath.canvasAnchorY + t.dy,
        ),
        pt,
      );
    }
  }
  @override
  bool shouldRepaint(_EdgePainter old) => old.e.length != e.length || old.p != p;
}

class _PhantomNode extends StatelessWidget {
  final PredictedEvent pred;
  final Color themeTint;
  const _PhantomNode({required this.pred, required this.themeTint});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 5,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                themeTint.withValues(alpha: 0.55),
                themeTint.withValues(alpha: 0.08),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1123).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: themeTint.withValues(alpha: 0.45), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pred.name,
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                pred.theme,
                style: GoogleFonts.jetBrainsMono(
                  color: themeTint.withValues(alpha: 0.85),
                  fontSize: 7,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmotionLegend extends StatelessWidget {
  final bool compact;
  const _EmotionLegend({this.compact = false});
  @override
  Widget build(BuildContext context) {
    const items = [
      ('Joy / Excited', Color(0xFFFFB300)),
      ('Calm / Peaceful', Color(0xFF4EE2C9)),
      ('Stressed / Anxious', Color(0xFFFF5252)),
      ('Sad', Color(0xFF5C6BC0)),
      ('Overwhelmed', Color(0xFFE040FB)),
      ('Neutral', Color(0xFF00E5FF)),
    ];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 6 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFF070814).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'EMOTIONS',
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 7,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: e.$2),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      e.$1,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: compact ? 8 : 9,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
class _StartNode extends StatelessWidget {
  final String label;
  const _StartNode({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 15,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          label.length > 6 ? label.substring(5) : label,
          style: GoogleFonts.jetBrainsMono(
            color: Colors.black,
            fontSize: 6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _NodeWidget extends StatelessWidget {
  final LifeCanvasNode node;
  final Color color;
  final double pulse;
  final bool isPhantom;
  const _NodeWidget({
    required this.node,
    required this.color,
    required this.pulse,
    this.isPhantom = false,
  });
  @override Widget build(BuildContext context) {
    if (node.type == 'THEME') {
      final sz = 48.0 + 20.0 * node.importance;
      return Container(
        width: sz, height: sz,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0F1123).withValues(alpha: 0.85),
          border: Border.all(color: color.withValues(alpha: 0.5 + 0.3 * math.sin(pulse * math.pi * 2)), width: 1.5 + 1.0 * node.importance),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: sz * 0.4),
          ],
        ),
        child: Center(
          child: Text(
            node.label.substring(0, math.min(4, node.label.length)).toUpperCase(),
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
      );
    }

    final sz = 15.0 + node.importance * 20.0;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Glistening outer neon ring
        Container(
          width: sz + 6,
          height: sz + 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isPhantom
                  ? const Color(0xFFBF5AF2).withValues(alpha: 0.6)
                  : color.withValues(
                      alpha: 0.35 + 0.25 * math.sin(pulse * math.pi * 2),
                    ),
              width: isPhantom ? 1.5 : 1.0,
              style: isPhantom ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
        ),
        Container(
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPhantom ? color.withValues(alpha: 0.25) : color,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.65), blurRadius: sz * 0.5, spreadRadius: 1),
            ],
          ),
          child: Center(
            child: Icon(
              node.emotion == 'excited' || node.emotion == 'joy' ? LucideIcons.smile : LucideIcons.activity,
              color: Colors.black.withValues(alpha: 0.75),
              size: sz * 0.45,
            ),
          ),
        ),
        Positioned(
          bottom: -22,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF070814).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
            ),
            child: Text(
              node.label,
              style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.9), fontSize: 8.0, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}
