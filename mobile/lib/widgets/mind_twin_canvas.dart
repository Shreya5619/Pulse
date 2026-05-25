import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/lifecanvas_service.dart';

// ─── Force-directed Mind Twin canvas ─────────────────────────────────────────
class MindTwinCanvas extends StatefulWidget {
  final List<MindNode> nodes;
  final List<MindEdge> edges;
  final MindNode? selectedNode;
  final Function(MindNode) onNodeTap;
  final Function(MindNode) onNodeLongPress;
  final Function(MindEdge) onEdgeAdded;
  final VoidCallback? onBackgroundTap;

  const MindTwinCanvas({
    super.key,
    required this.nodes,
    required this.edges,
    required this.selectedNode,
    required this.onNodeTap,
    required this.onNodeLongPress,
    required this.onEdgeAdded,
    this.onBackgroundTap,
  });

  @override
  State<MindTwinCanvas> createState() => MindTwinCanvasState();
}

class MindTwinCanvasState extends State<MindTwinCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _physics;
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _pan = Offset.zero;
  MindNode? _draggedNode;
  
  double _canvasW = 400.0;
  double _canvasH = 600.0;

  @override
  void initState() {
    super.initState();
    _physics = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..addListener(_tick);
    _runLayoutBurst();
  }

  void _runLayoutBurst() {
    if (!mounted) return;
    _physics.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant MindTwinCanvas old) {
    super.didUpdateWidget(old);
    if (widget.nodes.length != old.nodes.length) {
      _seedPositions();
      _runLayoutBurst();
    }
  }

  void _seedPositions() {
    final rng = math.Random(42);
    final cx = _canvasW / 2;
    final cy = _canvasH / 2;
    for (final n in widget.nodes) {
      if (n.x == 0 && n.y == 0) {
        n.x = cx + (rng.nextDouble() - 0.5) * 200;
        n.y = cy + (rng.nextDouble() - 0.5) * 200;
      }
    }
  }

  void _tick() {
    // If a node is being dragged, we don't apply physics updates to it
    const repulsion = 2500.0;
    const spring = 0.06;
    const damping = 0.82;
    const restLen = 90.0;
    const gravity = 0.02;

    final cx = _canvasW / 2;
    final cy = _canvasH / 2;

    final vx = <String, double>{};
    final vy = <String, double>{};

    // Central gravity
    for (final n in widget.nodes) {
      if (n.id == _draggedNode?.id) continue;
      final dx = cx - n.x, dy = cy - n.y;
      vx[n.id] = (vx[n.id] ?? 0) + dx * gravity;
      vy[n.id] = (vy[n.id] ?? 0) + dy * gravity;
    }

    // Repulsion
    for (int i = 0; i < widget.nodes.length; i++) {
      for (int j = i + 1; j < widget.nodes.length; j++) {
        final a = widget.nodes[i], b = widget.nodes[j];
        final dx = b.x - a.x, dy = b.y - a.y;
        final dist = math.max(math.sqrt(dx * dx + dy * dy), 0.1);
        if (dist < 400.0) {
          final force = repulsion / (dist * dist);
          final fx = force * dx / dist, fy = force * dy / dist;
          if (a.id != _draggedNode?.id) {
            vx[a.id] = (vx[a.id] ?? 0) - fx;
            vy[a.id] = (vy[a.id] ?? 0) - fy;
          }
          if (b.id != _draggedNode?.id) {
            vx[b.id] = (vx[b.id] ?? 0) + fx;
            vy[b.id] = (vy[b.id] ?? 0) + fy;
          }
        }
      }
    }

    // Spring attraction along edges
    for (final e in widget.edges) {
      final src = widget.nodes.firstWhere((n) => n.id == e.sourceId, orElse: () => widget.nodes.first);
      final tgt = widget.nodes.firstWhere((n) => n.id == e.targetId, orElse: () => widget.nodes.last);
      final dx = tgt.x - src.x, dy = tgt.y - src.y;
      final dist = math.max(math.sqrt(dx * dx + dy * dy), 0.1);
      final force = spring * (dist - restLen);
      final fx = force * dx / dist, fy = force * dy / dist;
      if (src.id != _draggedNode?.id) {
        vx[src.id] = (vx[src.id] ?? 0) + fx;
        vy[src.id] = (vy[src.id] ?? 0) + fy;
      }
      if (tgt.id != _draggedNode?.id) {
        vx[tgt.id] = (vx[tgt.id] ?? 0) - fx;
        vy[tgt.id] = (vy[tgt.id] ?? 0) - fy;
      }
    }

    // Parent-child attraction
    for (final node in widget.nodes) {
      if (node.parentId != null) {
        final parent = widget.nodes.firstWhere((n) => n.id == node.parentId, orElse: () => node);
        if (parent != node) {
          final dx = parent.x - node.x, dy = parent.y - node.y;
          final dist = math.max(math.sqrt(dx * dx + dy * dy), 0.1);
          final force = spring * 0.8 * (dist - 50);
          if (node.id != _draggedNode?.id) {
            vx[node.id] = (vx[node.id] ?? 0) + force * dx / dist;
            vy[node.id] = (vy[node.id] ?? 0) + force * dy / dist;
          }
        }
      }
    }

    setState(() {
      for (final n in widget.nodes) {
        if (n.id == _draggedNode?.id) continue;
        n.x += ((vx[n.id] ?? 0) * damping).clamp(-12.0, 12.0);
        n.y += ((vy[n.id] ?? 0) * damping).clamp(-12.0, 12.0);
      }
    });
  }

  void resetView() => setState(() { _scale = 1.0; _pan = Offset.zero; });

  Offset _toGraph(Offset screen) =>
      (screen - _pan - Offset(_canvasW / 2, _canvasH / 2)) / _scale;

  MindNode? _hitTest(Offset graphPos) {
    for (final n in widget.nodes.reversed) {
      final r = n.type == 'CATEGORY' ? 30.0 : 20.0;
      if ((Offset(n.x, n.y) - graphPos).distance < r) return n;
    }
    return null;
  }

  @override
  void dispose() {
    _physics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasW = constraints.maxWidth;
        _canvasH = constraints.maxHeight;
        
        return GestureDetector(
          onTapDown: (d) {
            final hit = _hitTest(_toGraph(d.localPosition));
            if (hit != null) {
              widget.onNodeTap(hit);
            } else {
              widget.onBackgroundTap?.call();
            }
          },
          onLongPressStart: (d) {
            final hit = _hitTest(_toGraph(d.localPosition));
            if (hit != null) widget.onNodeLongPress(hit);
          },
          onScaleStart: (details) {
            final hit = _hitTest(_toGraph(details.localFocalPoint));
            if (hit != null) {
              _draggedNode = hit;
            } else {
              _draggedNode = null;
              _baseScale = _scale;
            }
          },
          onScaleUpdate: (details) {
            if (_draggedNode != null) {
              final graphPos = _toGraph(details.localFocalPoint);
              setState(() {
                _draggedNode!.x = graphPos.dx;
                _draggedNode!.y = graphPos.dy;
              });
            } else {
              setState(() {
                _scale = (_baseScale * details.scale).clamp(0.15, 6.0);
                _pan += details.focalPointDelta;
              });
            }
          },
          onScaleEnd: (_) {
            if (_draggedNode != null) {
              _draggedNode = null;
              _runLayoutBurst();
            }
          },
          child: CustomPaint(
            painter: _MindTwinPainter(
              nodes: widget.nodes,
              edges: widget.edges,
              selectedNode: widget.selectedNode,
              scale: _scale,
              pan: _pan,
            ),
            child: const SizedBox.expand(),
          ),
        );
      }
    );
  }
}

class _MindTwinPainter extends CustomPainter {
  final List<MindNode> nodes;
  final List<MindEdge> edges;
  final MindNode? selectedNode;
  final double scale;
  final Offset pan;

  _MindTwinPainter({
    required this.nodes, required this.edges,
    required this.selectedNode, required this.scale, required this.pan,
  });

  Offset _project(MindNode n, Size size) =>
      Offset(n.x * scale + pan.dx + size.width / 2, n.y * scale + pan.dy + size.height / 2);

  static const _typeColors = {
    'CATEGORY': Color(0xFF00E5FF),
    'HOLDER': Color(0xFFBF5AF2),
    'EVENT': Color(0xFF4EE2C9),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;

    // Edges
    for (final e in edges) {
      final src = nodes.firstWhere((n) => n.id == e.sourceId, orElse: () => nodes.first);
      final tgt = nodes.firstWhere((n) => n.id == e.targetId, orElse: () => nodes.last);
      final sp = _project(src, size), tp = _project(tgt, size);
      canvas.drawLine(sp, tp, Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1.2);
      if (e.directed) {
        final dir = (tp - sp) / (tp - sp).distance;
        final tip = tp - dir * 20;
        final perp = Offset(-dir.dy, dir.dx) * 6;
        final path = Path()..moveTo(tp.dx, tp.dy)
          ..lineTo((tip + perp).dx, (tip + perp).dy)
          ..lineTo((tip - perp).dx, (tip - perp).dy)..close();
        canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.25));
      }
    }

    // Nodes
    for (final n in nodes) {
      final pos = _project(n, size);
      final c = _typeColors[n.type] ?? const Color(0xFF4EE2C9);
      final r = n.type == 'CATEGORY' ? 28.0 : n.type == 'HOLDER' ? 24.0 : 18.0;
      final isSource = selectedNode?.id == n.id;

      if (isSource) {
        canvas.drawCircle(pos, r + 8, Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      }

      p.color = const Color(0xFF0B0D1E);
      canvas.drawCircle(pos, r, p);
      canvas.drawCircle(pos, r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSource ? 2.0 : 1.2
        ..color = isSource ? const Color(0xFFFFB300) : c.withValues(alpha: 0.5));

      final tp2 = TextPainter(
        text: TextSpan(
          text: n.name.length > 10 ? '${n.name.substring(0, 10)}..' : n.name,
          style: TextStyle(
            color: Colors.white.withValues(alpha: n.type == 'CATEGORY' ? 0.9 : 0.7),
            fontSize: n.type == 'CATEGORY' ? 10 : 8,
            fontWeight: n.type == 'CATEGORY' ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp2.paint(canvas, pos - Offset(tp2.width / 2, tp2.height / 2));
    }
  }

  @override
  bool shouldRepaint(_MindTwinPainter o) => true;
}
