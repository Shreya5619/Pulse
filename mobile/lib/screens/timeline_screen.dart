import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  String _filter = "Now";

  final List<Map<String, dynamic>> _mockEvents = [
    {
      "time": "09:18",
      "type": "Context",
      "agent": "Context",
      "text": "Calendar: 'Design review' at 10:00 added",
      "isNow": true,
    },
    {
      "time": "09:20",
      "type": "Risk",
      "agent": "Risk",
      "text": "Lateness risk jumped from 0.35 → 0.72",
      "isNow": false,
    },
    {
      "time": "09:22",
      "type": "Action",
      "agent": "Planner",
      "text": "Suggested: Leave at 9:35, switch to cab.",
      "isNow": false,
    },
    {
      "time": "09:25",
      "type": "Outcome",
      "agent": "Guardian",
      "text": "Accepted · ETA now 9:57, risk down to 0.21",
      "isNow": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                itemCount: _mockEvents.length,
                itemBuilder: (context, index) => _buildTimelineItem(_mockEvents[index], index == 0, index == _mockEvents.length - 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: ["Past", "Now", "Next 90 min"].map((f) {
          final isSelected = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.white30)),
              selected: isSelected,
              onSelected: (val) => setState(() => _filter = f),
              backgroundColor: Colors.white.withOpacity(0.05),
              selectedColor: AppColors.primary.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? AppColors.primary : Colors.white10)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> event, bool isFirst, bool isLast) {
    final color = _getColorForType(event['type']);
    final isReplayHighlight = event['isNow'];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 40,
            child: Text(
              event['time'],
              style: GoogleFonts.outfit(fontSize: 10, color: Colors.white30, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          // Connector column
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1, color: Colors.white10),
                ),
            ],
          ),
          const SizedBox(width: 20),
          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isReplayHighlight ? color.withOpacity(0.08) : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isReplayHighlight ? color.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _badge(event['type'], color),
                      Text(
                        event['agent'],
                        style: GoogleFonts.outfit(fontSize: 8, color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event['text'],
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
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
}
