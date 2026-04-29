import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import '../widgets/route_eta_strip.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  String _filter = "All";

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        // Sort events by timestamp (newest first)
        final allEvents = state.timelineEvents.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        final filteredEvents = _filterEvents(allEvents, state);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildFilterBar(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: RouteEtaStrip(isMini: true),
                ),
                Expanded(
                  child: filteredEvents.isEmpty 
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        itemCount: filteredEvents.length,
                        itemBuilder: (context, index) {
                          final event = filteredEvents[index];
                          final isLast = index == filteredEvents.length - 1;
                          final isFirst = index == 0;
                          
                          // In replay mode, highlight events that happened "just now"
                          final isNew = state.isReplayMode && 
                              state.simulatedTime != null &&
                              state.simulatedTime!.difference(event.timestamp).inSeconds.abs() < 10;

                          return _buildTimelineItem(context, state, event, isFirst, isLast, isNew);
                        },
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<TimelineEvent> _filterEvents(List<TimelineEvent> events, AppState state) {
    if (_filter == "All") return events;
    if (_filter == "Risks") return events.where((e) => e.type == "Risk").toList();
    if (_filter == "Actions") return events.where((e) => e.type == "Action" || e.type == "Outcome").toList();
    return events;
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Pulse Timeline",
            style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            "Chronological chain of reasoning and actions",
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.white30),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: ["All", "Risks", "Actions"].map((f) {
          final isSelected = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.white30)),
              selected: isSelected,
              onSelected: (val) => setState(() => _filter = f),
              backgroundColor: Colors.white.withOpacity(0.05),
              selectedColor: AppColors.primary.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isSelected ? AppColors.primary.withOpacity(0.5) : Colors.white10),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, AppState state, TimelineEvent event, bool isFirst, bool isLast, bool isNew) {
    final color = _getColorForType(event.type);
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Column
          SizedBox(
            width: 45,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                DateFormat.Hm().format(event.timestamp),
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white30, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Connector Line
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isNew ? color : color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  boxShadow: isNew ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)] : null,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: Colors.white.withOpacity(0.05)),
                ),
            ],
          ),
          const SizedBox(width: 20),
          // Event Card
          Expanded(
            child: GestureDetector(
              onTap: () => _handleEventTap(context, state, event),
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isNew ? color.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isNew ? color.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _badge(event.type, color),
                        Text(
                          event.agent.toUpperCase(),
                          style: GoogleFonts.outfit(fontSize: 9, color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      event.text,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.9), 
                        fontSize: 14, 
                        height: 1.4,
                        fontWeight: isNew ? FontWeight.w600 : FontWeight.normal
                      ),
                    ),
                    if (event.data != null && event.type == "Risk")
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          "Score: ${event.data!['level'] ?? 'N/A'}",
                          style: TextStyle(fontSize: 10, color: color.withOpacity(0.7), fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case "Context": return Colors.blueAccent;
      case "Risk": return Colors.orangeAccent;
      case "Action": return Colors.purpleAccent;
      case "Outcome": return Colors.greenAccent;
      default: return Colors.white30;
    }
  }

  void _handleEventTap(BuildContext context, AppState state, TimelineEvent event) {
    if (event.type == "Risk") {
       // Navigate to Graph Explanation if nodeId exists
       final risks = event.data?['risks'] as List<dynamic>?;
       if (risks != null && risks.isNotEmpty) {
         // For now, jump to first risk explanation
         debugPrint("Timeline: Tapped risk event, jumping to explanation...");
       }
    } else if (event.type == "Action") {
       // Jump to Actions screen
       debugPrint("Timeline: Tapped action event, jumping to Actions screen...");
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.clock, size: 48, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          const Text("No events recorded yet", style: TextStyle(color: Colors.white24)),
        ],
      ),
    );
  }
}
