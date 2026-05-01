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
  List<dynamic> _suggestedActions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExplanation();
  }

  Future<void> _loadExplanation() async {
    final state = Provider.of<AppState>(context, listen: false);

    // Load both explanation and suggested actions in parallel
    final results = await Future.wait([
      state.fetchGraphExplanation(widget.nodeId),
      state.fetchSuggestedActions(widget.riskType, nodeId: widget.nodeId),
    ]);

    if (mounted) {
      setState(() {
        _explanation = results[0] as Map<String, dynamic>?;
        _suggestedActions = results[1] as List<dynamic>;
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _explanation == null
          ? const Center(
              child: Text(
                "Explanation not available",
                style: TextStyle(color: Colors.white54),
              ),
            )
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
                  if (_suggestedActions.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      "Suggested Interventions",
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._buildActionCards(),
                  ],
                  const SizedBox(height: 40),
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
        (e) =>
            (e['from'] == node['id'] && e['to'] == targetId) ||
            (e['to'] == node['id'] && e['from'] == targetId),
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
                        _formatEdgeExplanation(edge),
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 10,
                        ),
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

  List<Widget> _buildActionCards() {
    return _suggestedActions.map((action) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          borderColor: AppColors.primary.withValues(alpha: 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.zap,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      action['title'] ?? "Intervention",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                action['description'] ?? "",
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Logic to execute action
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    "EXECUTE INTERVENTION",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
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
      case 'NOW':
        icon = LucideIcons.clock;
        color = Colors.blueAccent;
        break;
      case 'PLACE':
        icon = LucideIcons.mapPin;
        color = Colors.greenAccent;
        break;
      case 'APPOINTMENT':
        icon = LucideIcons.calendar;
        color = Colors.redAccent;
        break;
      case 'BATTERY_STATE':
        icon = LucideIcons.battery;
        color = Colors.orangeAccent;
        break;
      case 'MESSAGE_OBLIGATION':
        icon = LucideIcons.messageSquare;
        color = Colors.purpleAccent;
        break;
      default:
        icon = LucideIcons.circle;
        color = Colors.white30;
    }
    return Icon(icon, color: color, size: size);
  }

  String _formatEdgeExplanation(Map<String, dynamic> edge) {
    final type = edge['type'] as String?;
    final weight = edge['weight'] as num?;
    final roundedWeight = weight?.toStringAsFixed(1) ?? "0.0";

    switch (type) {
      case 'TRAVEL':
        return "Requires $roundedWeight min travel";
      case 'URGENCY':
        return "Starts in $roundedWeight min";
      case 'ENERGY_COST':
        return "Power drain impact: $roundedWeight";
      case 'INTERRUPTION':
        return "Response urgency: $roundedWeight";
      default:
        return "${type ?? 'Related'} (influence: $roundedWeight)";
    }
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
              "${(s * 100).toStringAsFixed(1)}%",
              style: TextStyle(
                color: s > 0.7
                    ? Colors.redAccent
                    : s > 0.4
                    ? Colors.orangeAccent
                    : Colors.greenAccent,
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
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            color: s > 0.7
                ? Colors.redAccent
                : s > 0.4
                ? Colors.orangeAccent
                : Colors.greenAccent,
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
