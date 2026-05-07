import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';

void _showAddEventDialog(BuildContext context, {DayPulseBlock? existingBlock}) {
  final titleController = TextEditingController(text: existingBlock?.title);
  final locationController = TextEditingController(
    text: existingBlock?.locationText,
  );
  final startLocationController = TextEditingController(
    text: existingBlock?.startLocation?['name'],
  );
  DateTime startTime =
      existingBlock?.startTime ?? DateTime.now().add(const Duration(hours: 1));
  DateTime endTime =
      existingBlock?.endTime ?? DateTime.now().add(const Duration(hours: 2));
  String selectedCategory = existingBlock?.category ?? 'buffer';
  bool isRecurring = existingBlock?.days != null;
  List<int> selectedDays =
      existingBlock?.days ?? [1, 2, 3, 4, 5]; // Default M-F
  Map<String, dynamic>? currentStartLoc = existingBlock?.startLocation;
  Map<String, dynamic>? currentDestLoc; // For destination coords if needed

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          existingBlock == null ? "Add Activity" : "Edit Activity",
          style: GoogleFonts.outfit(color: Colors.white),
        ),
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
                controller: startLocationController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Source Location (Optional)",
                  labelStyle: TextStyle(color: Colors.white54),
                  hintText: "e.g. Home",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      LucideIcons.mapPin,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      final loc = context
                          .read<AppState>()
                          .deviceContext
                          .location;
                      setDialogState(() {
                        startLocationController.text = "Current Location";
                        currentStartLoc = {
                          'lat': loc.latitude,
                          'lon': loc.longitude,
                          'name': "Current Location",
                        };
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Destination Location (Optional)",
                  labelStyle: TextStyle(color: Colors.white54),
                  hintText: "e.g. Office HQ",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      LucideIcons.mapPin,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      final loc = context
                          .read<AppState>()
                          .deviceContext
                          .location;
                      setDialogState(() {
                        locationController.text = "Current Location";
                        currentDestLoc = {
                          'lat': loc.latitude,
                          'lon': loc.longitude,
                          'name': "Current Location",
                        };
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Category",
                    style: GoogleFonts.outfit(color: Colors.white70),
                  ),
                  DropdownButton<String>(
                    dropdownColor: AppColors.background,
                    value: selectedCategory,
                    items: ['sleep', 'study', 'commute', 'buffer']
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedCategory = val!),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "Remember choice",
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  "Make this a recurring routine",
                  style: GoogleFonts.outfit(
                    color: Colors.white24,
                    fontSize: 11,
                  ),
                ),
                value: isRecurring,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => setDialogState(() => isRecurring = val),
              ),
              if (isRecurring) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: List.generate(7, (index) {
                    final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                    final isSelected = selectedDays.contains(index);
                    return GestureDetector(
                      onTap: () => setDialogState(() {
                        if (isSelected)
                          selectedDays.remove(index);
                        else
                          selectedDays.add(index);
                      }),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            days[index],
                            style: GoogleFonts.outfit(
                              color: isSelected ? Colors.white : Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 24),
              _TimePickerRow(
                label: "Start",
                time: startTime,
                onTap: () async {
                  final time = await showTimePicker(
                    context: dialogContext,
                    initialTime: TimeOfDay.fromDateTime(startTime),
                  );
                  if (time != null) {
                    setDialogState(() {
                      startTime = DateTime(
                        startTime.year,
                        startTime.month,
                        startTime.day,
                        time.hour,
                        time.minute,
                      );
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
                    context: dialogContext,
                    initialTime: TimeOfDay.fromDateTime(endTime),
                  );
                  if (time != null) {
                    setDialogState(() {
                      endTime = DateTime(
                        endTime.year,
                        endTime.month,
                        endTime.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          if (existingBlock != null)
            TextButton(
              onPressed: () {
                context.read<AppState>().deleteDayPulseItem(
                  existingBlock.eventId,
                  existingBlock.type == 'routine',
                );
                Navigator.pop(dialogContext);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                final startLoc = startLocationController.text.isNotEmpty
                    ? (currentStartLoc != null &&
                              startLocationController.text == "Current Location"
                          ? currentStartLoc
                          : {'name': startLocationController.text})
                    : null;

                final destLoc = locationController.text.isNotEmpty
                    ? (currentDestLoc != null &&
                              locationController.text == "Current Location"
                          ? currentDestLoc
                          : null) // Backend will geocode if it's just text
                    : null;

                // If destLoc is null but locationController has text, we pass the text as 'location'
                // but the API also supports 'location_text' in the 'updates' map.

                if (existingBlock == null) {
                  context.read<AppState>().addDayPulseEvent(
                    titleController.text,
                    startTime,
                    endTime,
                    location: locationController.text.isNotEmpty
                        ? locationController.text
                        : null,
                    startLocation: startLoc,
                    destinationLocation: destLoc,
                    category: selectedCategory,
                    isRecurring: isRecurring,
                    days: isRecurring ? selectedDays : null,
                  );
                } else {
                  context
                      .read<AppState>()
                      .modifyDayPulse(existingBlock.eventId, {
                        'title': titleController.text,
                        'startTime': startTime.toIso8601String(),
                        'endTime': endTime.toIso8601String(),
                        'location_text': locationController.text,
                        'start_location': startLoc,
                        'destination_location': destLoc,
                        'category': selectedCategory,
                        'isRecurring': isRecurring,
                        'days': isRecurring ? selectedDays : null,
                      });
                }
                Navigator.pop(dialogContext);
              }
            },
            child: Text(existingBlock == null ? "Add" : "Save"),
          ),
        ],
      ),
    ),
  );
}

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
              "daily pulse",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            Text(
              DateFormat('EEEE, MMM d').format(DateTime.now()),
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white38),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 20),
            onPressed: () => _showAddEventDialog(context),
          ),
          TextButton.icon(
            onPressed: () => context.read<AppState>().optimizeDayPulse(),
            icon: const Icon(
              LucideIcons.sparkles,
              size: 16,
              color: Colors.amber,
            ),
            label: Text(
              "Optimize",
              style: GoogleFonts.outfit(color: Colors.amber, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => context.read<AppState>().fetchDayPulse(),
          ),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) => FloatingActionButton(
          backgroundColor: AppColors.primary,
          onPressed: () => _showAddEventDialog(context),
          child: const Icon(LucideIcons.plus, color: Colors.white),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, state, child) {
          final blocks = state.dayPulseBlocks;

          return Column(
            children: [
              if (state.isDayPulseProposed)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.alertTriangle,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Draft changes pending",
                          style: GoogleFonts.outfit(
                            color: Colors.amber,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          LucideIcons.x,
                          color: Colors.white54,
                          size: 18,
                        ),
                        onPressed: () => state.discardDayPulseProposed(),
                        tooltip: "Discard",
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                        ),
                        onPressed: () => state.persistDayPulse(),
                        icon: const Icon(LucideIcons.check, size: 16),
                        label: const Text(
                          "Save All",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (blocks.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text("No activities detected for today."),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    itemCount: blocks.length,
                    itemBuilder: (context, index) {
                      final block = blocks[index];
                      return _TimelineBlock(
                        block: block,
                        isLast: index == blocks.length - 1,
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TimePickerRow extends StatelessWidget {
  final String label;
  final DateTime time;
  final VoidCallback onTap;

  const _TimePickerRow({
    required this.label,
    required this.time,
    required this.onTap,
  });

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
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                DateFormat('HH:mm').format(time),
                style: GoogleFonts.outfit(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
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

    Color blockColor = isRoutine
        ? Colors.white.withValues(alpha: 0.02)
        : Colors.white.withValues(alpha: 0.05);

    // Specified palette
    if (block.category == 'sleep') {
      blockColor = const Color(
        0xFF3F51B5,
      ).withValues(alpha: 0.15); // Deep Indigo
    }
    if (block.category == 'study') {
      blockColor = const Color(0xFF2ECC71).withValues(alpha: 0.15); // Emerald
    }
    if (block.category == 'commute') {
      blockColor = const Color(0xFFF1C40F).withValues(alpha: 0.15); // Amber
    }
    if (block.category == 'buffer') {
      blockColor = const Color(0xFF1ABC9C).withValues(alpha: 0.15); // Teal
    }
    if (block.locationText != null && block.locationText!.isNotEmpty) {
      blockColor = const Color(
        0xFF673AB7,
      ).withValues(alpha: 0.15); // Royal Purple
    }

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
                    boxShadow: isRoutine
                        ? []
                        : [
                            BoxShadow(
                              color:
                                  (hasHighRisk
                                          ? AppColors.danger
                                          : AppColors.primary)
                                      .withValues(alpha: 0.4),
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
                      color: Colors.white.withValues(alpha: 0.05),
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
                onLongPress: () =>
                    _showAddEventDialog(context, existingBlock: block),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasHighRisk
                          ? AppColors.danger.withValues(alpha: 0.3)
                          : (isRoutine
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.white.withValues(alpha: 0.05)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  block.title,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: isRoutine
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    color: isRoutine
                                        ? Colors.white70
                                        : Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                if (block.locationText != null &&
                                    block.locationText!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.mapPin,
                                        size: 10,
                                        color: Colors.white38,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          block.locationText!,
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            color: Colors.white38,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      if (block.etaMinutes != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            "ETA: ${block.etaMinutes}m",
                                            style: GoogleFonts.outfit(
                                              fontSize: 9,
                                              color: Colors.amber,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ] else if (block.batteryAtStart !=
                                          null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                (block.batteryAtStart! < 20
                                                        ? AppColors.danger
                                                        : Colors.orange)
                                                    .withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            "BATT: ${block.batteryAtStart!.round()}%",
                                            style: GoogleFonts.outfit(
                                              fontSize: 9,
                                              color: block.batteryAtStart! < 20
                                                  ? AppColors.danger
                                                  : Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!isRoutine) _RiskBadges(risks: block.risks),
                        ],
                      ),
                      if (block.risks.isNotEmpty ||
                          block.suggestion != null) ...[
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
                              color:
                                  block.suggestion?['actionId'] ==
                                      'OPTIMIZED_SHIFT'
                                  ? Colors.amber
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                block.suggestion?['title'] ??
                                    "Monitoring status...",
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color:
                                      (block.suggestion?['actionId'] ==
                                                  'OPTIMIZED_SHIFT'
                                              ? Colors.amber
                                              : AppColors.primary)
                                          .withValues(alpha: 0.9),
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
          color: AppColors.success.withValues(alpha: 0.1),
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

    return Wrap(
      spacing: 4,
      children: risks.map((risk) {
        IconData icon;
        Color color = risk.level == 'high' ? AppColors.danger : Colors.orange;

        switch (risk.type) {
          case 'lateness':
            icon = LucideIcons.clock;
            break;
          case 'battery':
            icon = LucideIcons.batteryLow;
            break;
          case 'overload':
            icon = LucideIcons.users;
            break;
          default:
            icon = LucideIcons.alertTriangle;
        }

        return Tooltip(
          message: risk.explanation ?? risk.label,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
        );
      }).toList(),
    );
  }
}
