import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/lifecanvas_service.dart';
import '../services/lifecanvas_diary.dart';
import '../widgets/mind_twin_canvas.dart';

class MindTwinScreen extends StatefulWidget {
  const MindTwinScreen({super.key});
  @override
  State<MindTwinScreen> createState() => _MindTwinScreenState();
}

class _MindTwinScreenState extends State<MindTwinScreen> {
  final GlobalKey<MindTwinCanvasState> _canvasKey = GlobalKey();
  List<MindNode> _nodes = [];
  List<MindEdge> _edges = [];
  MindNode? _selectedNode;
  bool _brainstormOpen = false;
  bool _aiProcessing = false;
  bool _mapReducing = false;
  final List<TextEditingController> _brainstormCtrls = [TextEditingController()];

  @override
  void initState() {
    super.initState();
    _loadGraph();
  }

  Future<void> _loadGraph() async {
    final rawNodes = await lifecanvasDiary.getMindNodes();
    final rawEdges = await lifecanvasDiary.getMindEdges();
    final rng = math.Random(42);
    setState(() {
      _nodes = rawNodes.map((m) => MindNode(
        id: m['id'] as String,
        name: m['name'] as String,
        type: m['type'] as String? ?? 'EVENT',
        parentId: m['parentId'] as String?,
        x: (rng.nextDouble() - 0.5) * 400,
        y: (rng.nextDouble() - 0.5) * 400,
      )).toList();
      _edges = rawEdges.map((m) => MindEdge(
        sourceId: m['sourceId'] as String,
        targetId: m['targetId'] as String,
        directed: m['directed'] as bool? ?? false,
      )).toList();
    });
  }

  Future<void> _save() async {
    await lifecanvasDiary.saveMindNodes(_nodes.map((n) => {'id': n.id, 'name': n.name, 'type': n.type, 'parentId': n.parentId}).toList());
    await lifecanvasDiary.saveMindEdges(_edges.map((e) => {'sourceId': e.sourceId, 'targetId': e.targetId, 'directed': e.directed}).toList());
  }

  void _addNode(String type) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1123),
        title: Text('Add ${type == 'CATEGORY' ? 'Category' : 'Event'}', style: GoogleFonts.outfit(color: Colors.white)),
        content: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: 'Name...', hintStyle: TextStyle(color: Colors.white30), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: Text('Add', style: TextStyle(color: type == 'CATEGORY' ? const Color(0xFF00E5FF) : const Color(0xFF4EE2C9)))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final id = '${type.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
      setState(() => _nodes.add(MindNode(id: id, name: name, type: type)));
      _save();
    }
  }

  void _deleteSelected() {
    if (_selectedNode == null) { _showSnack('Long-press a node to select it first'); return; }
    setState(() {
      _nodes.removeWhere((n) => n.id == _selectedNode!.id);
      _edges.removeWhere((e) => e.sourceId == _selectedNode!.id || e.targetId == _selectedNode!.id);
      _selectedNode = null;
    });
    _save();
  }

  void _groupSelected() async {
    final checkedIds = <String>{};
    final ctrl = TextEditingController();
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF0F1123),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Group Nodes (AI Cluster)', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Select multiple nodes to group them under a new holder blob category.', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter group/holder name...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _nodes.where((n) => n.type != 'HOLDER').length,
                  itemBuilder: (ctx, i) {
                    final n = _nodes.where((n) => n.type != 'HOLDER').toList()[i];
                    final isChecked = checkedIds.contains(n.id);
                    return CheckboxListTile(
                      value: isChecked,
                      activeColor: const Color(0xFFBF5AF2),
                      title: Text(n.name, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                      subtitle: Text(n.type, style: GoogleFonts.jetBrainsMono(color: Colors.white30, fontSize: 9)),
                      onChanged: (val) {
                        setModalState(() {
                          if (val == true) {
                            checkedIds.add(n.id);
                          } else {
                            checkedIds.remove(n.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) {
                    _showSnack('Please enter a group name');
                    return;
                  }
                  if (checkedIds.isEmpty) {
                    _showSnack('Please select at least one node');
                    return;
                  }
                  
                  final pid = 'holder_${DateTime.now().millisecondsSinceEpoch}';
                  setState(() {
                    _nodes.add(MindNode(
                      id: pid,
                      name: name,
                      type: 'HOLDER',
                      x: (math.Random().nextDouble() - 0.5) * 200,
                      y: (math.Random().nextDouble() - 0.5) * 200,
                    ));
                    for (final nid in checkedIds) {
                      final idx = _nodes.indexWhere((node) => node.id == nid);
                      if (idx >= 0) {
                        _nodes[idx].parentId = pid;
                      }
                    }
                  });
                  _save();
                  Navigator.pop(context);
                  _showSnack('Group created successfully!');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFBF5AF2), Color(0xFF00E5FF)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('CREATE GROUP CLUSTER', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNodeTap(MindNode n) async {
    if (_selectedNode == null) {
      setState(() => _selectedNode = n);
    } else {
      if (_selectedNode!.id == n.id) {
        setState(() => _selectedNode = null);
        return;
      }
      
      final existingIdx = _edges.indexWhere((e) =>
          (e.sourceId == _selectedNode!.id && e.targetId == n.id) ||
          (e.sourceId == n.id && e.targetId == _selectedNode!.id));
          
      if (existingIdx >= 0) {
        setState(() {
          _edges.removeAt(existingIdx);
        });
        await _save();
        _showSnack('Connection removed.');
      } else {
        final directed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF0F1123),
            title: Text('Create Connection', style: GoogleFonts.outfit(color: Colors.white)),
            content: Text('Create directed arrow from "${_selectedNode!.name}" to "${n.name}"?', style: GoogleFonts.outfit(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Undirected Line', style: TextStyle(color: Colors.white38)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Directed Arrow', style: TextStyle(color: Color(0xFF00E5FF))),
              ),
            ],
          ),
        );
        
        if (directed != null) {
          setState(() {
            _edges.add(MindEdge(
              sourceId: _selectedNode!.id,
              targetId: n.id,
              directed: directed,
            ));
          });
          await _save();
          _showSnack('Connection created.');
        }
      }
      setState(() => _selectedNode = null);
    }
  }

  Future<void> _processBrainstorm() async {
    final items = _brainstormCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (items.isEmpty) return;
    setState(() => _aiProcessing = true);
    try {
      final updates = await lifecanvasService.brainstormToMindMap(items: items, existingNodes: _nodes);
      for (final u in updates) {
        if (!_nodes.any((n) => n.id == u.id)) {
          String? pid = u.parentId;
          if (pid != null && pid.isNotEmpty) {
            final parentCatName = pid;
            final catId = parentCatName.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
            if (!_nodes.any((n) => n.id == catId)) {
              setState(() {
                _nodes.add(MindNode(
                  id: catId,
                  name: parentCatName[0].toUpperCase() + parentCatName.substring(1),
                  type: 'CATEGORY',
                  x: (math.Random().nextDouble() - 0.5) * 300,
                  y: (math.Random().nextDouble() - 0.5) * 300,
                ));
              });
            }
            pid = catId;
          }

          setState(() {
            _nodes.add(MindNode(
              id: u.id,
              name: u.name,
              type: 'EVENT',
              parentId: pid,
              x: (math.Random().nextDouble() - 0.5) * 300,
              y: (math.Random().nextDouble() - 0.5) * 300,
            ));
            if (pid != null && pid.isNotEmpty) {
              _edges.add(MindEdge(sourceId: pid, targetId: u.id, directed: true));
            }
          });
        }
      }
      await _save();
      setState(() { _brainstormCtrls.clear(); _brainstormCtrls.add(TextEditingController()); });
    } finally {
      setState(() => _aiProcessing = false);
    }
  }

  Future<void> _applyMapReduce() async {
    if (_nodes.isEmpty) { _showSnack('No nodes to reduce.'); return; }
    Navigator.pop(context);
    setState(() => _mapReducing = true);
    try {
      final result = await lifecanvasService.mapReduceMindGraph(
        nodes: _nodes, edges: _edges,
      );
      setState(() {
        // Delete nominated nodes
        for (final id in result.toDelete) {
          _nodes.removeWhere((n) => n.id == id);
          _edges.removeWhere((e) => e.sourceId == id || e.targetId == id);
        }
        // Rename nominated nodes
        result.toRename.forEach((id, newName) {
          final idx = _nodes.indexWhere((n) => n.id == id);
          if (idx >= 0) {
            final old = _nodes[idx];
            _nodes[idx] = MindNode(
              id: old.id, name: newName, type: old.type,
              parentId: old.parentId, x: old.x, y: old.y,
            );
          }
        });
        // Add new category nodes
        for (final n in result.toAdd) {
          if (!_nodes.any((x) => x.id == n.id)) {
            n.x = (math.Random().nextDouble() - 0.5) * 250;
            n.y = (math.Random().nextDouble() - 0.5) * 250;
            _nodes.add(n);
          }
        }
        // Add new edges
        for (final e in result.edgesToAdd) {
          final srcExists = _nodes.any((n) => n.id == e.sourceId);
          final tgtExists = _nodes.any((n) => n.id == e.targetId);
          final alreadyExists = _edges.any((x) =>
            (x.sourceId == e.sourceId && x.targetId == e.targetId) ||
            (x.sourceId == e.targetId && x.targetId == e.sourceId));
          if (srcExists && tgtExists && !alreadyExists) _edges.add(e);
        }
        // Delete nominated edges
        for (final e in result.edgesToDelete) {
          _edges.removeWhere((x) =>
            (x.sourceId == e.sourceId && x.targetId == e.targetId) ||
            (x.sourceId == e.targetId && x.targetId == e.sourceId));
        }
      });
      await _save();
      _canvasKey.currentState?.runLayoutBurst();
      _showSnack('✨ ${result.summary}');
    } catch (e) {
      _showSnack('Map & Reduce failed: $e');
    } finally {
      setState(() => _mapReducing = false);
    }
  }

  void _showTidyModal() {
    final pruned = <String>{};
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          height: MediaQuery.of(context).size.height * 0.78,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF0F1123),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Tidy Mind Map', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                // Map & Reduce button
                GestureDetector(
                  onTap: _applyMapReduce,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFBF5AF2), Color(0xFF00E5FF)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      const Icon(LucideIcons.zap, size: 12, color: Colors.white),
                      const SizedBox(width: 5),
                      Text('MAP & REDUCE', style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text('Uncheck to prune nodes. Or let AI auto-clean with Map & Reduce.',
                style: GoogleFonts.outfit(color: Colors.white30, fontSize: 11)),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.builder(
                  itemCount: _nodes.length,
                  itemBuilder: (context, i) {
                    final n = _nodes[i];
                    final isMarked = pruned.contains(n.id);
                    final color = n.type == 'CATEGORY'
                        ? const Color(0xFF00E5FF)
                        : n.type == 'HOLDER'
                            ? const Color(0xFFBF5AF2)
                            : const Color(0xFF4EE2C9);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isMarked ? Colors.red.withValues(alpha: 0.08) : color.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isMarked ? Colors.red.withValues(alpha: 0.3) : color.withValues(alpha: 0.15)),
                      ),
                      child: CheckboxListTile(
                        value: !isMarked,
                        activeColor: color,
                        checkColor: Colors.black,
                        title: Text(n.name, style: GoogleFonts.outfit(
                          color: isMarked ? Colors.white38 : Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          decoration: isMarked ? TextDecoration.lineThrough : null,
                        )),
                        subtitle: Text(n.type, style: GoogleFonts.jetBrainsMono(
                          color: color.withValues(alpha: 0.5), fontSize: 9)),
                        onChanged: (v) {
                          setModal(() {
                            if (v == false) pruned.add(n.id);
                            else pruned.remove(n.id);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              if (pruned.isNotEmpty) ...
              [
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _nodes.removeWhere((n) => pruned.contains(n.id));
                      for (final id in pruned) {
                        _edges.removeWhere((e) => e.sourceId == id || e.targetId == id);
                      }
                    });
                    _save();
                    Navigator.pop(context);
                    _showSnack('Pruned ${pruned.length} node(s).');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Center(child: Text(
                      'PRUNE ${pruned.length} NODE${pruned.length == 1 ? "" : "S"}',
                      style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    )),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: const Color(0xFF1E1E2E), content: Text(msg, style: GoogleFonts.outfit(color: Colors.white70))));

  @override
  void dispose() {
    for (final c in _brainstormCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070814),
      body: SafeArea(
        child: Column(children: [
          // ── Top Bar ──────────────────────────────────────────────────────────
          Container(
            height: 56, padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)))),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 17, color: Colors.white70), onPressed: () => Navigator.pop(context)),
              Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                ShaderMask(shaderCallback: (r) => const LinearGradient(colors: [Color(0xFFBF5AF2), Color(0xFF00E5FF)]).createShader(r),
                  child: Text('Mind Twin', style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
                Text('Semantic Knowledge Graph', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 9)),
              ]),
              const Spacer(),
              _iconBtn(LucideIcons.plusCircle, const Color(0xFF4EE2C9), () => _addNode('EVENT'), tooltip: 'Add Event'),
              _iconBtn(LucideIcons.layers, const Color(0xFF00E5FF), () => _addNode('CATEGORY'), tooltip: 'Add Category'),
              _iconBtn(LucideIcons.listChecks, Colors.white54, _showTidyModal, tooltip: 'Tidy / Map & Reduce'),
              if (_mapReducing)
                const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFBF5AF2))))
              else
                _iconBtn(LucideIcons.rotateCcw, Colors.white38, () => _canvasKey.currentState?.resetView(), tooltip: 'Reset View'),
            ]),
          ),

          // ── Connection hint banner ───────────────────────────────────────────
          if (_selectedNode != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFFFFB300).withValues(alpha: 0.12),
              child: Row(children: [
                const Icon(LucideIcons.arrowRight, color: Color(0xFFFFB300), size: 13),
                const SizedBox(width: 8),
                Text('Tap another node to connect to "${_selectedNode!.name}"  —  tap same to cancel',
                  style: GoogleFonts.outfit(color: const Color(0xFFFFB300), fontSize: 11)),
              ]),
            ),

          // ── Canvas ───────────────────────────────────────────────────────────
          Expanded(
            child: MindTwinCanvas(
              key: _canvasKey,
              nodes: _nodes,
              edges: _edges,
              selectedNode: _selectedNode,
              onNodeTap: _handleNodeTap,
              onNodeLongPress: (n) => setState(() => _selectedNode = n),
              onEdgeAdded: (e) { setState(() => _edges.add(e)); _save(); },
              onBackgroundTap: () => setState(() => _selectedNode = null),
            ),
          ),

          // ── Action bar ───────────────────────────────────────────────────────
          Container(
            height: 48, padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF07091A),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
            ),
            child: Row(children: [
              _actionChip(LucideIcons.trash2, 'Delete', const Color(0xFFFF5252), _deleteSelected),
              const SizedBox(width: 8),
              _actionChip(LucideIcons.group, 'Group', const Color(0xFFBF5AF2), _groupSelected),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _brainstormOpen = !_brainstormOpen),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _brainstormOpen ? const Color(0xFF00E5FF).withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: _brainstormOpen ? 0.4 : 0.2)),
                  ),
                  child: Row(children: [
                    Icon(LucideIcons.brain, size: 13, color: const Color(0xFF00E5FF).withValues(alpha: _brainstormOpen ? 1.0 : 0.5)),
                    const SizedBox(width: 6),
                    Text('Brainstorm', style: GoogleFonts.outfit(color: const Color(0xFF00E5FF).withValues(alpha: _brainstormOpen ? 1.0 : 0.5), fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Brainstorm Panel ─────────────────────────────────────────────────
          if (_brainstormOpen)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF06080F),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MAP WITH AI', style: GoogleFonts.jetBrainsMono(color: Colors.white30, fontSize: 9, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: _brainstormCtrls.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Text('•', style: TextStyle(color: Colors.white30)),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(
                          controller: _brainstormCtrls[i],
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            border: InputBorder.none,
                            hintText: 'Something to map...',
                            hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 13),
                          ),
                        )),
                      ]),
                    ),
                  ),
                ),
                Row(children: [
                  GestureDetector(
                    onTap: () => setState(() => _brainstormCtrls.add(TextEditingController())),
                    child: Text('+ add line', style: GoogleFonts.outfit(color: Colors.white30, fontSize: 12)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _aiProcessing ? null : _processBrainstorm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: _aiProcessing ? null : const LinearGradient(colors: [Color(0xFFBF5AF2), Color(0xFF00E5FF)]),
                        color: _aiProcessing ? Colors.white12 : null,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: _aiProcessing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF00E5FF)))
                          : Text('MIND-MAP WITH AI ▶', style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap, {String? tooltip}) =>
    IconButton(icon: Icon(icon, size: 18, color: color), tooltip: tooltip, onPressed: onTap);

  Widget _actionChip(IconData icon, String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.outfit(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
}
