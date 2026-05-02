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
          TextButton.icon(
            onPressed: () => context.read<AppState>().optimizeDayPulse(),
            icon: const Icon(LucideIcons.sparkles, size: 16, color: Colors.amber),
            label: Text("Optimize", style: GoogleFonts.outfit(color: Colors.amber, fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => context.read<AppState>().fetchDayPulse(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddEventDialog(context),
        child: const Icon(LucideIcons.plus, color: Colors.white),
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

  void _showAddEventDialog(BuildContext context) {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    DateTime startTime = DateTime.now().add(const Duration(hours: 1));
    DateTime endTime = DateTime.now().add(const Duration(hours: 2));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text("Add Activity", style: GoogleFonts.outfit(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Name",
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Location (Optional)",
                    labelStyle: TextStyle(color: Colors.white54),
                    hintText: "e.g. Office HQ",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
                _TimePickerRow(
                  label: "Start",
                  time: startTime,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(startTime),
                    );
                    if (time != null) {
                      setDialogState(() {
                        startTime = DateTime(startTime.year, startTime.month, startTime.day, time.hour, time.minute);
                        if (endTime.isBefore(startTime)) {
                          endTime = startTime.add(const Duration(hours: 1));
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _TimePickerRow(
                  label: "End",
                  time: endTime,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(endTime),
                    );
                    if (time != null) {
                      setDialogState(() {
                        endTime = DateTime(endTime.year, endTime.month, endTime.day, time.hour, time.minute);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  context.read<AppState>().addDayPulseEvent(
                    titleController.text, 
                    startTime, 
                    endTime, 
                    location: locationController.text.isNotEmpty ? locationController.text : null
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerRow extends StatelessWidget {
  final String label;
  final DateTime time;
  final VoidCallback onTap;

  const _TimePickerRow({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(color: Colors.white70)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                DateFormat('HH:mm').format(time),
                style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
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
    final isRoutine = block.type == 'routine';

    Color blockColor = isRoutine ? Colors.white10 : Colors.white.withOpacity(0.05);
    if (block.category == 'sleep') blockColor = Colors.grey.withOpacity(0.1);
    if (block.category == 'study') blockColor = Colors.indigo.withOpacity(0.15);
    if (block.category == 'commute') blockColor = Colors.blueGrey.withOpacity(0.15);
    if (block.category == 'buffer') blockColor = Colors.green.withOpacity(0.1);

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
                    color: isRoutine ? Colors.white24 : Colors.white70,
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
                    color: isRoutine 
                      ? Colors.white12 
                      : (hasHighRisk ? AppColors.danger : AppColors.primary),
                    shape: BoxShape.circle,
                    boxShadow: isRoutine ? [] : [
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
                      color: Colors.white.withOpacity(0.05),
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
                onLongPress: isRoutine ? null : () => _showEditDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasHighRisk 
                        ? AppColors.danger.withOpacity(0.3) 
                        : (isRoutine ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.05)),
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
                                fontWeight: isRoutine ? FontWeight.normal : FontWeight.bold,
                                color: isRoutine ? Colors.white38 : Colors.white,
                              ),
                            ),
                          ),
                          if (!isRoutine) _RiskBadges(risks: block.risks),
                        ],
                      ),
                      if (block.risks.isNotEmpty || block.suggestion != null) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              block.suggestion?['actionId'] == 'OPTIMIZED_SHIFT' 
                                ? LucideIcons.sparkles 
                                : LucideIcons.zap, 
                              size: 14, 
                              color: block.suggestion?['actionId'] == 'OPTIMIZED_SHIFT' 
                                ? Colors.amber 
                                : AppColors.primary
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                block.suggestion?['title'] ?? "Monitoring status...",
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: (block.suggestion?['actionId'] == 'OPTIMIZED_SHIFT' 
                                    ? Colors.amber 
                                    : AppColors.primary).withOpacity(0.9),
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
