import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/glass_card.dart';
import '../theme/colors.dart';

class GraphExplanationScreen extends StatefulWidget {
  final String nodeId;
  final String riskType;

  const GraphExplanationScreen({
    super.key,
    required this.nodeId,
    required this.riskType,
  });

  @override
  State<GraphExplanationScreen> createState() => _GraphExplanationScreenState();
}

class _GraphExplanationScreenState extends State<GraphExplanationScreen> {
  Map<String, dynamic>? _explanation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExplanation();
  }

  Future<void> _loadExplanation() async {
    final state = Provider.of<AppState>(context, listen: false);
    final data = await state.fetchGraphExplanation(widget.nodeId);
    if (mounted) {
      setState(() {
        _explanation = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Graph Explanation",
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _explanation == null
              ? const Center(child: Text("Explanation not available", style: TextStyle(color: Colors.white54)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTargetNodeCard(),
                      const SizedBox(height: 24),
                      Text(
                        "Contributing Factors",
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white30,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._buildNeighborCards(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTargetNodeCard() {
    final target = _explanation!['target'];
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _getNodeIcon(target['type']),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target['label'] ?? "Target Node",
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      target['type'] ?? "UNKNOWN",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildScoreBar(target['scores']?[widget.riskType] ?? 0.0),
        ],
      ),
    );
  }

  List<Widget> _buildNeighborCards() {
    final nodes = _explanation!['nodes'] as List<dynamic>;
    final edges = _explanation!['edges'] as List<dynamic>;
    final targetId = widget.nodeId;

    // Filter out the target node itself
    final neighbors = nodes.where((n) => n['id'] != targetId).toList();

    return neighbors.map((node) {
      final edge = edges.firstWhere(
        (e) => (e['from'] == node['id'] && e['to'] == targetId) || (e['to'] == node['id'] && e['from'] == targetId),
        orElse: () => null,
      );

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _getNodeIcon(node['type'], size: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node['label'] ?? "Neighbor",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (edge != null)
                      Text(
                        "${edge['type']} (weight: ${edge['weight']})",
                        style: const TextStyle(color: Colors.white30, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _getNodeIcon(String? type, {double size = 24}) {
    IconData icon;
    Color color;
    switch (type) {
      case 'NOW': icon = LucideIcons.clock; color = Colors.blueAccent; break;
      case 'PLACE': icon = LucideIcons.mapPin; color = Colors.greenAccent; break;
      case 'APPOINTMENT': icon = LucideIcons.calendar; color = Colors.redAccent; break;
      case 'BATTERY_STATE': icon = LucideIcons.battery; color = Colors.orangeAccent; break;
      case 'MESSAGE_OBLIGATION': icon = LucideIcons.messageSquare; color = Colors.purpleAccent; break;
      default: icon = LucideIcons.circle; color = Colors.white30;
    }
    return Icon(icon, color: color, size: size);
  }

  Widget _buildScoreBar(num score) {
    final s = score.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Risk Contribution",
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            Text(
              "${(s * 100).toStringAsFixed(0)}%",
              style: TextStyle(
                color: s > 0.7 ? Colors.redAccent : s > 0.4 ? Colors.orangeAccent : Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: s,
            backgroundColor: Colors.white.withOpacity(0.05),
            color: s > 0.7 ? Colors.redAccent : s > 0.4 ? Colors.orangeAccent : Colors.greenAccent,
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
