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
import 'mind_twin_screen.dart';

enum ViewMode { galaxy, river, timeline }
enum InputMode { ingest, ask, predict }

class LifeCanvasScreen extends StatefulWidget {
  const LifeCanvasScreen({super.key});
  @override
  State<LifeCanvasScreen> createState() => _LifeCanvasScreenState();
}

class _LifeCanvasScreenState extends State<LifeCanvasScreen> with TickerProviderStateMixin {
  ViewMode _viewMode = ViewMode.galaxy;
  InputMode _inputMode = InputMode.ingest;
  DateTime _timelineBaseDate = DateTime.now();

  final TextEditingController _journal = TextEditingController();
  final FocusNode _journalFocus = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  
  // InteractiveViewer tracking for Gantt sync
  final TransformationController _viewCtrl = TransformationController();
  double _zoomScale = 1.0;
  double _viewOffsetHours = 0.0;

  late AnimationController _pulse;
  late AnimationController _orbit;

  bool _isProcessing = false;
  final List<AgentStep> _steps = [];
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _orbit = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
    
    _viewCtrl.addListener(() {
      final s = _viewCtrl.value.getMaxScaleOnAxis();
      final dx = _viewCtrl.value.getTranslation().x;
      setState(() {
        _zoomScale = s;
        _viewOffsetHours = -dx / (200.0 * s);
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().fetchLifeCanvasGraph();
      _resetView();
    });
  }

  void _resetView() {
    final size = MediaQuery.of(context).size;
    final screenW = size.width;
    final screenH = size.height;
    final tx = -1000.0 + screenW / 2;
    final ty = -600.0 + screenH / 2;
    setState(() {
      _viewCtrl.value = Matrix4.identity()..translate(tx, ty);
    });
  }

  @override
  void dispose() {
    _pulse.dispose(); _orbit.dispose();
    _journal.dispose(); _journalFocus.dispose();
    _viewCtrl.dispose();
    super.dispose();
  }

  // ─── Timeline Mode Positions ────────────────────────────────────────────────
  Map<String, Offset> _timelinePos(List<LifeCanvasNode> nodes) {
    final pos = <String, Offset>{};
    final events = nodes.where((n) => n.type == 'LIFE_EVENT').toList();
    final startOfTodayMs = DateTime(_timelineBaseDate.year, _timelineBaseDate.month, _timelineBaseDate.day).millisecondsSinceEpoch;
    
    for (int i = 0; i < events.length; i++) {
      final n = events[i];
      final dt = n.timestamp ?? n.createdAt;
      final msOffset = dt.millisecondsSinceEpoch - startOfTodayMs;
      final hoursOffset = msOffset / 3600000.0;
      final graphX = hoursOffset * 200.0;
      final graphY = (i % 2 == 0 ? -1 : 1) * (40.0 + (i % 3) * 30.0);
      pos[n.id] = Offset(graphX, graphY);
    }
    return pos;
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
    
    final ok = await appState.ingestLifeCanvasLog(text.trim());

    setState(() => _statusText = 'Applying mutations...');
    _addStep(4, 'result', 'Proposing Graph Mutations', ok ? 'Validated node + theme edges ready to commit.' : 'Using rule-based fallback extraction.');
    await Future.delayed(const Duration(milliseconds: 500));

    _addStep(5, ok ? 'final' : 'error', ok ? 'Galaxy Updated' : 'Partial Update', ok ? 'Memory node persisted. Galaxy is evolving.' : 'JSON store fallback was used.');
    _stopProcessing(ok ? null : 'Failed to ingest properly.');
    if (ok) appState.fetchLifeCanvasGraph();
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
      _scaffoldKey.currentState?.openEndDrawer();
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

    Map<String, Offset> positions;
    if (_viewMode == ViewMode.galaxy) positions = _galaxyPos(graph.nodes);
    else if (_viewMode == ViewMode.river) positions = _riverPos(graph.nodes);
    else positions = _timelinePos(graph.nodes);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF070814),
      drawer: LifeCanvasSidebar(
        graph: graph,
        isGalaxyView: _viewMode == ViewMode.galaxy,
        onViewToggle: (v) { setState(() => _viewMode = v ? ViewMode.galaxy : ViewMode.river); Navigator.pop(context); },
        onRefresh: () { context.read<AppState>().fetchLifeCanvasGraph(); Navigator.pop(context); },
      ),
      endDrawer: Drawer(
        width: 320,
        backgroundColor: const Color(0xFF0F1123),
        child: SafeArea(
          child: LifeCanvasReasoningPanel(
            steps: _steps,
            isActive: _isProcessing,
            statusText: _statusText,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
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
                _viewTab('Galaxy', ViewMode.galaxy), const SizedBox(width: 8),
                _viewTab('River', ViewMode.river), const SizedBox(width: 8),
                _viewTab('Timeline', ViewMode.timeline),
                IconButton(icon: const Icon(LucideIcons.zoomIn, size: 16, color: Colors.white54), onPressed: () => setState(() => _viewCtrl.value = _viewCtrl.value.clone()..scale(1.3))),
                IconButton(icon: const Icon(LucideIcons.zoomOut, size: 16, color: Colors.white54), onPressed: () => setState(() => _viewCtrl.value = _viewCtrl.value.clone()..scale(1 / 1.3))),
                IconButton(icon: const Icon(LucideIcons.refreshCw, size: 14, color: Colors.white54), tooltip: 'Reset View', onPressed: _resetView),
              ]),
            ),

            // ── Canvas Area ───────────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: AnimatedBuilder(animation: _pulse, builder: (_, __) => CustomPaint(painter: _StarfieldPainter(_pulse.value)))),
                  
                  isLoading
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 1.5),
                          const SizedBox(height: 14),
                          Text('Loading cognitive universe...', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13)),
                        ]))
                      : InteractiveViewer(
                          transformationController: _viewCtrl,
                          minScale: 0.001, maxScale: 10.0,
                          constrained: false,
                          boundaryMargin: const EdgeInsets.all(4000),
                          child: SizedBox(
                            width: 2000, height: 1200,
                            child: Stack(clipBehavior: Clip.none, children: [
                              // Edges
                              Positioned.fill(child: AnimatedBuilder(animation: _orbit, builder: (_, __) => CustomPaint(painter: _EdgePainter(graph.edges, graph.nodes, positions, _viewMode == ViewMode.galaxy, _orbit.value)))),
                              
                              // Phantoms (Predict mode)
                              if (_viewMode == ViewMode.timeline)
                                ...state.predictions.map((pred) {
                                  final graphX = (pred.futureHour * 200.0);
                                  final graphY = 80.0 + (pred.name.hashCode % 100);
                                  return Positioned(
                                    left: 1000 + graphX - 20, top: 600 + graphY - 20,
                                    child: _PhantomNode(pred: pred, pulse: _pulse.value),
                                  );
                                }),

                              // Nodes
                              ...graph.nodes.map((node) {
                                final p = positions[node.id];
                                if (p == null) return const SizedBox.shrink();
                                return Positioned(
                                  left: 1000 + p.dx - 26, top: 600 + p.dy - 26,
                                  child: GestureDetector(
                                    onTap: () => _showDetail(node),
                                    child: AnimatedBuilder(animation: _pulse, builder: (_, __) => _NodeWidget(node: node, color: _emotionColor(node.emotion), pulse: _pulse.value)),
                                  ),
                                );
                              }),
                            ]),
                          ),
                        ),
                  
                  // Anchored Timeline Axis (renders on top, fixed at the top!)
                  if (_viewMode == ViewMode.timeline && !isLoading)
                    Positioned(
                      top: 0, left: 0, right: 0, height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF070814).withValues(alpha: 0.85),
                          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                        ),
                        child: CustomPaint(
                          painter: LifeCanvasTimelinePainter(
                            viewOffsetHours: _viewOffsetHours,
                            zoomScale: _zoomScale,
                            baseDate: _timelineBaseDate,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Gantt Strip ───────────────────────────────────────────────────
            if (_viewMode == ViewMode.timeline)
              LifeCanvasGantt(
                stats: state.usageStats,
                predictions: state.predictions,
                viewOffsetHours: _viewOffsetHours,
                zoomScale: _zoomScale,
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

  // Layout math...
  Map<String, Offset> _galaxyPos(List<LifeCanvasNode> nodes) {
    final pos = <String, Offset>{};
    final themes = nodes.where((n) => n.type == 'THEME').toList();
    final events = nodes.where((n) => n.type == 'LIFE_EVENT').toList();

    // 1. Core Center
    pos['core_self'] = Offset.zero;

    // 2. Position themes in a close inner ring rotating slowly
    for (int i = 0; i < themes.length; i++) {
      final angle = (i * 2 * math.pi / themes.length) + (_orbit.value * 2 * math.pi * 0.1);
      final r = 160.0;
      pos[themes[i].id] = Offset(r * math.cos(angle), r * math.sin(angle));
    }

    // 3. Position events in a breathtaking multi-armed twisted galaxy spiral
    const arms = 3;
    for (int i = 0; i < events.length; i++) {
      final ev = events[i];
      final armIndex = i % arms;
      final armAngle = armIndex * (2 * math.pi / arms);
      
      final a = 200.0;
      final b = 40.0;
      // Spread nodes along the spiral arm
      final theta = (i ~/ arms) * 0.4 + (_orbit.value * 2 * math.pi * 0.04);
      final r = a + b * theta;
      
      // Introduce twist/spiral angle offsets
      final finalAngle = armAngle + (theta * 0.95);
      
      pos[ev.id] = Offset(r * math.cos(finalAngle), r * math.sin(finalAngle));
    }
    return pos;
  }

  Map<String, Offset> _riverPos(List<LifeCanvasNode> nodes) {
    final pos = <String, Offset>{};
    final events = nodes.where((n) => n.type == 'LIFE_EVENT').toList()..sort((a, b) => (a.timestamp ?? a.createdAt).compareTo(b.timestamp ?? b.createdAt));
    final startX = -((events.length - 1) * 240.0) / 2;
    for (int i = 0; i < events.length; i++) {
      final x = startX + i * 240.0;
      final y = 130.0 * math.sin(i * 0.9 + _orbit.value * 2 * math.pi * 0.15); // Organic wave ripple
      pos[events[i].id] = Offset(x, y);
    }
    return pos;
  }

  // Modals and colors...
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
  final List<LifeCanvasEdge> e; final List<LifeCanvasNode> n; final Map<String, Offset> p; final bool g; final double o;
  _EdgePainter(this.e,this.n,this.p,this.g,this.o);
  @override void paint(Canvas canvas, Size size) { final pt=Paint()..style=PaintingStyle.stroke; for(var ed in e){ final s=p[ed.sourceId], t=p[ed.targetId]; if(s==null||t==null) continue; pt..color=const Color(0xFF00E5FF).withValues(alpha: 0.15*ed.strength)..strokeWidth=1.3*ed.strength; canvas.drawLine(Offset(1000+s.dx, 600+s.dy), Offset(1000+t.dx, 600+t.dy), pt); } }
  @override bool shouldRepaint(_EdgePainter old) => true;
}
class _PhantomNode extends StatelessWidget {
  final PredictedEvent pred; final double pulse; const _PhantomNode({required this.pred, required this.pulse});
  @override Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFBF5AF2).withValues(alpha: 0.7), width: 1.5, style: BorderStyle.solid)),
      child: Center(child: Text('?', style: GoogleFonts.outfit(color: const Color(0xFFBF5AF2), fontWeight: FontWeight.bold))),
    );
  }
}
class _NodeWidget extends StatelessWidget {
  final LifeCanvasNode node; final Color color; final double pulse; const _NodeWidget({required this.node, required this.color, required this.pulse});
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

    final sz = 28.0 + 30.0 * node.importance;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Glistening outer neon ring
        Container(
          width: sz + 6, height: sz + 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.35 + 0.25 * math.sin(pulse * math.pi * 2)), width: 1.0),
          ),
        ),
        // Glow effect
        Container(
          width: sz, height: sz,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
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
