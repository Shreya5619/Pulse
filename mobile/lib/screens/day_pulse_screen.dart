import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';

class DayPulseScreen extends StatefulWidget {
  const DayPulseScreen({super.key});

  @override
  State<DayPulseScreen> createState() => _DayPulseScreenState();
}

class _DayPulseScreenState extends State<DayPulseScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().fetchDayPulse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Day Pulse",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            Text(
              DateFormat('EEEE, MMM d').format(DateTime.now()),
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white38),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => context.read<AppState>().fetchDayPulse(),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, child) {
          final blocks = state.dayPulseBlocks;
          if (blocks.isEmpty) {
            return const Center(
              child: Text("No activities detected for today."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            itemCount: blocks.length,
            itemBuilder: (context, index) {
              final block = blocks[index];
              return _TimelineBlock(block: block, isLast: index == blocks.length - 1);
            },
          );
        },
      ),
    );
  }
}

class _TimelineBlock extends StatelessWidget {
  final DayPulseBlock block;
  final bool isLast;

  const _TimelineBlock({required this.block, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final startTime = DateFormat('HH:mm').format(block.startTime);
    final endTime = DateFormat('HH:mm').format(block.endTime);
    final hasHighRisk = block.risks.any((r) => r.level == 'high');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Column
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Text(
                  startTime,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                Text(
                  endTime,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Colors.white24,
                  ),
                ),
              ],
            ),
          ),
          
          // Vertical Line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: hasHighRisk ? AppColors.danger : AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (hasHighRisk ? AppColors.danger : AppColors.primary).withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
              ],
            ),
          ),

          // Content Block
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: GestureDetector(
                onLongPress: () => _showEditDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasHighRisk 
                        ? AppColors.danger.withOpacity(0.3) 
                        : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              block.title,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          _RiskBadges(risks: block.risks),
                        ],
                      ),
                      if (block.risks.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(LucideIcons.zap, size: 14, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                block.suggestion?['title'] ?? "Monitoring status...",
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.primary.withOpacity(0.9),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text("Modify Schedule", style: GoogleFonts.outfit(color: Colors.white)),
        content: Text(
          "Do you want to simulate moving '${block.title}' 30 minutes later to resolve potential conflicts?",
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AppState>().modifyDayPulse(block.eventId, {
                'start_offset_minutes': 30
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Simulating ripple effect...")),
              );
            },
            child: const Text("Modify"),
          ),
        ],
      ),
    );
  }
}

class _RiskBadges extends StatelessWidget {
  final List<DayPulseRisk> risks;
  const _RiskBadges({required this.risks});

  @override
  Widget build(BuildContext context) {
    if (risks.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          "SAFE",
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppColors.success,
          ),
        ),
      );
    }

    return Row(
      children: risks.map((risk) {
        IconData icon;
        Color color = risk.level == 'high' ? AppColors.danger : Colors.orange;
        
        switch (risk.type) {
          case 'lateness': icon = LucideIcons.clock; break;
          case 'battery': icon = LucideIcons.batteryLow; break;
          case 'overload': icon = LucideIcons.users; break;
          default: icon = LucideIcons.alertTriangle;
        }

        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Tooltip(
            message: risk.label,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: color),
            ),
          ),
        );
      }).toList(),
    );
  }
}
