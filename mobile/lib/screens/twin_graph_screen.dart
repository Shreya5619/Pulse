import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/twin_graph.dart';
import '../theme/colors.dart';

class TwinGraphScreen extends StatefulWidget {
  const TwinGraphScreen({super.key});

  @override
  State<TwinGraphScreen> createState() => _TwinGraphScreenState();
}

class _TwinGraphScreenState extends State<TwinGraphScreen>
    with SingleTickerProviderStateMixin {
  // Pan & zoom state
  Offset _offset = Offset.zero;
  double _scale = 1.0;
  Offset _focalPoint = Offset.zero;
  double _startScale = 1.0;
  Offset _startOffset = Offset.zero;

  // Selected node for detail
  TwinNode? _selectedNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().fetchTwinGraph();
    });
  }

  void _onScaleStart(ScaleStartDetails d) {
    _focalPoint = d.focalPoint;
    _startScale = _scale;
    _startOffset = _offset;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      _scale = (_startScale * d.scale).clamp(0.15, 4.0);
      final delta = d.focalPoint - _focalPoint;
      _offset = _startOffset + delta;
    });
  }

  void _onTapUp(TapUpDetails d, List<TwinNode> nodes) {
    // Convert tap point to graph coordinates
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2 + _offset.dx;
    final cy = size.height / 2 + _offset.dy;

    for (final node in nodes) {
      final sx = cx + node.x * _scale;
      final sy = cy + node.y * _scale;
      final dist = (d.localPosition - Offset(sx, sy)).distance;
      if (dist < 30 * _scale) {
        setState(() => _selectedNode = _selectedNode?.id == node.id ? null : node);
        return;
      }
    }
    setState(() => _selectedNode = null);
  }

  Color _nodeColor(String type, double risk) {
    switch (type) {
      case 'person': return AppColors.primary;
      case 'event':
        return risk > 0.7 ? AppColors.danger : (risk > 0.4 ? Colors.orange : AppColors.success);
      case 'battery': return risk > 0.5 ? Colors.orange : Colors.lightBlueAccent;
      case 'notification': return Colors.blueAccent;
      case 'preference': return Colors.amber;
      case 'location': return Colors.tealAccent;
      case 'trait': return Colors.purpleAccent;
      case 'interest': return Colors.pinkAccent;
      case 'sentiment': return Colors.cyanAccent;
      default: return Colors.grey;
    }
  }

  IconData _nodeIcon(String type) {
    switch (type) {
      case 'person': return LucideIcons.user;
      case 'event': return LucideIcons.calendar;
      case 'battery': return LucideIcons.battery;
      case 'notification': return LucideIcons.bell;
      case 'preference': return LucideIcons.settings;
      case 'location': return LucideIcons.mapPin;
      case 'trait': return LucideIcons.fingerprint;
      case 'interest': return LucideIcons.heart;
      case 'sentiment': return LucideIcons.smile;
      default: return LucideIcons.helpCircle;
    }
  }

  void _resetView() {
    setState(() {
      _offset = Offset.zero;
      _scale = 1.0;
      _selectedNode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Digital Twin",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.brain, color: Colors.purpleAccent),
            tooltip: "Self-Reflection",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Chrona is reflecting on your day...")),
              );
              context.read<AppState>().triggerSelfReflection();
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.sparkles, color: AppColors.primary),
            tooltip: "Summary",
            onPressed: () => _showSummary(context),
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white54),
            tooltip: "Refresh",
            onPressed: () {
              _resetView();
              context.read<AppState>().fetchTwinGraph();
            },
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, child) {
          final graph = state.twinGraph;
          final error = state.twinGraphError;

          if (graph == null) {
            if (error != null) {
              return _buildError(context, error);
            }
            return const Center(child: CircularProgressIndicator());
          }

          if (graph.nodes.isEmpty) {
            return _buildEmpty(context);
          }

          return Stack(
            children: [
              // The interactive graph canvas
              GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onTapUp: (d) => _onTapUp(d, graph.nodes),
                child: CustomPaint(
                  painter: TwinGraphPainter(
                    nodes: graph.nodes,
                    edges: graph.edges,
                    offset: _offset,
                    scale: _scale,
                    selectedNode: _selectedNode,
                    nodeColorFn: _nodeColor,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),

              // Node detail card
              if (_selectedNode != null)
                Positioned(
                  bottom: 80,
                  left: 16,
                  right: 16,
                  child: _buildNodeCard(_selectedNode!),
                ),

              // Bottom status bar
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    '${graph.nodes.length} nodes  ·  Pinch to zoom  ·  Tap a node',
                    style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ),

              // Reset button
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'twin_reset',
                  backgroundColor: AppColors.surface,
                  onPressed: _resetView,
                  child: const Icon(LucideIcons.locate, color: Colors.white54, size: 18),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNodeCard(TwinNode node) {
    final color = _nodeColor(node.type, node.risk);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(_nodeIcon(node.type), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.label,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  node.type.toUpperCase(),
                  style: GoogleFonts.outfit(color: color, fontSize: 10, letterSpacing: 1),
                ),
                if (node.risk > 0)
                  Text(
                    'Risk: ${(node.risk * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.outfit(color: Colors.orange, fontSize: 11),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _selectedNode = null),
            child: const Icon(LucideIcons.x, color: Colors.white38, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.wifiOff, color: Colors.white30, size: 48),
            const SizedBox(height: 20),
            Text('Could not load Digital Twin',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<AppState>().fetchTwinGraph(),
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.brain, color: Colors.white24, size: 64),
          const SizedBox(height: 20),
          Text('Twin is learning…',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Send a context snapshot to populate your Digital Twin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white24, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.read<AppState>().fetchTwinGraph(),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSummary(BuildContext context) {
    context.read<AppState>().fetchTwinSummary();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer<AppState>(
        builder: (context, state, child) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.97),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  const Icon(LucideIcons.sparkles, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Text("Digital Twin Summary",
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: state.isTwinSummarizing
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 100),
                              child: Column(children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text("Synthesizing your digital identity...",
                                    style: TextStyle(color: Colors.white54)),
                              ]),
                            ),
                          )
                        : Text(
                            state.twinSummary ?? "No summary available.",
                            style: GoogleFonts.outfit(fontSize: 15, color: Colors.white70, height: 1.6),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Canvas Painter ──────────────────────────────────────────────────────────

class TwinGraphPainter extends CustomPainter {
  final List<TwinNode> nodes;
  final List<TwinEdge> edges;
  final Offset offset;
  final double scale;
  final TwinNode? selectedNode;
  final Color Function(String type, double risk) nodeColorFn;

  const TwinGraphPainter({
    required this.nodes,
    required this.edges,
    required this.offset,
    required this.scale,
    required this.selectedNode,
    required this.nodeColorFn,
  });

  Offset _toScreen(double nx, double ny, Size size) {
    // Center the graph on screen, then apply pan/zoom
    final cx = size.width / 2 + offset.dx;
    final cy = size.height / 2 + offset.dy;
    // Shift graph so it's centered around its own center (around 500,400)
    return Offset(cx + (nx - 500) * scale, cy + (ny - 400) * scale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background grid (subtle)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const gridSpacing = 60.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Build node position lookup
    final Map<String, Offset> positions = {};
    for (final node in nodes) {
      positions[node.id] = _toScreen(node.x, node.y, size);
    }

    // Draw edges
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final from = positions[edge.from];
      final to = positions[edge.to];
      if (from != null && to != null) {
        canvas.drawLine(from, to, edgePaint);
      }
    }

    // Draw nodes
    for (final node in nodes) {
      final pos = positions[node.id]!;
      final color = nodeColorFn(node.type, node.risk);
      final isSelected = selectedNode?.id == node.id;
      final radius = (node.type == 'person' ? 28.0 : 20.0) * scale.clamp(0.5, 2.0);

      // Glow for selected
      if (isSelected) {
        canvas.drawCircle(
          pos,
          radius + 8,
          Paint()..color = color.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }

      // Outer ring
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = color.withValues(alpha: isSelected ? 1.0 : 0.6)
          ..strokeWidth = isSelected ? 2.5 : 1.5
          ..style = PaintingStyle.stroke,
      );

      // Risk fill
      if (node.risk > 0) {
        final riskColor = node.risk > 0.7 ? Colors.red : Colors.orange;
        canvas.drawCircle(
          pos,
          radius * node.risk,
          Paint()..color = riskColor.withValues(alpha: 0.3),
        );
      }

      // Label
      final labelScale = scale.clamp(0.6, 2.0);
      final labelFontSize = (node.type == 'person' ? 11.0 : 9.0) * labelScale;
      final label = _truncate(node.label, 18);

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isSelected ? color : Colors.white70,
            fontSize: labelFontSize,
            fontWeight: node.type == 'person' ? FontWeight.bold : FontWeight.normal,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 100 * labelScale);

      tp.paint(
        canvas,
        pos + Offset(-tp.width / 2, radius + 4),
      );
    }
  }

  String _truncate(String s, int max) => s.length > max ? '${s.substring(0, max)}…' : s;

  @override
  bool shouldRepaint(TwinGraphPainter old) =>
      old.offset != offset ||
      old.scale != scale ||
      old.nodes != nodes ||
      old.selectedNode != selectedNode;
}
