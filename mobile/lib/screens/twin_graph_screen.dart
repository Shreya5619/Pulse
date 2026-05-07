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

class _TwinGraphScreenState extends State<TwinGraphScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().fetchTwinGraph();
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
          "Digital Twin Explorer",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.sparkles, color: AppColors.primary),
            onPressed: () => _showSummary(context),
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => context.read<AppState>().fetchTwinGraph(),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, child) {
          final graph = state.twinGraph;
          if (graph == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(1000),
            minScale: 0.1,
            maxScale: 2.0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: const Size(2000, 2000),
                  painter: EdgePainter(graph.edges, graph.nodes),
                ),
                ...graph.nodes.map(
                  (node) => Positioned(
                    left: node.x,
                    top: node.y,
                    child: TwinNodeWidget(node: node),
                  ),
                ),
              ],
            ),
          );
        },
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
              color: AppColors.surface.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(LucideIcons.sparkles, color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      "Digital Twin Summary",
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: state.isTwinSummarizing
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 100),
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text("Synthesizing your digital identity...",
                                      style: TextStyle(color: Colors.white54)),
                                ],
                              ),
                            ),
                          )
                        : Text(
                            state.twinSummary ?? "No summary available.",
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                              height: 1.6,
                            ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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

class EdgePainter extends CustomPainter {
  final List<TwinEdge> edges;
  final List<TwinNode> nodes;

  EdgePainter(this.edges, this.nodes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var edge in edges) {
      final fromNode = nodes.firstWhere((n) => n.id == edge.from);
      final toNode = nodes.firstWhere((n) => n.id == edge.to);

      // Node center offset (approx 40x40 for the icon container)
      const offset = 30.0;
      canvas.drawLine(
        Offset(fromNode.x + offset, fromNode.y + offset),
        Offset(toNode.x + offset, toNode.y + offset),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TwinNodeWidget extends StatelessWidget {
  final TwinNode node;

  const TwinNodeWidget({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (node.type) {
      case 'person':
        icon = LucideIcons.user;
        color = AppColors.primary;
        break;
      case 'event':
        icon = LucideIcons.calendar;
        color = node.risk > 0.7
            ? AppColors.danger
            : (node.risk > 0.4 ? Colors.orange : AppColors.success);
        break;
      case 'battery':
        icon = LucideIcons.battery;
        color = node.risk > 0.5 ? Colors.orange : AppColors.primary;
        break;
      case 'notification':
        icon = LucideIcons.bell;
        color = Colors.blueAccent;
        break;
      case 'preference':
        icon = LucideIcons.settings;
        color = Colors.amber;
        break;
      case 'location':
        icon = LucideIcons.mapPin;
        color = Colors.teal;
        break;
      case 'trait':
        icon = LucideIcons.fingerprint;
        color = Colors.purpleAccent;
        break;
      case 'interest':
        icon = LucideIcons.heart;
        color = Colors.pinkAccent;
        break;
      case 'sentiment':
        icon = LucideIcons.smile;
        color = Colors.cyanAccent;
        break;
      default:
        icon = LucideIcons.helpCircle;
        color = Colors.grey;
    }

    return Tooltip(
      message: node.label,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            child: Text(
              node.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
