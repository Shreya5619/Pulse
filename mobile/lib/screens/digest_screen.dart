import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';
import '../providers/app_state.dart';
import '../models/device_context.dart'; // Using the model from current project

class DigestScreen extends StatefulWidget {
  const DigestScreen({super.key});

  @override
  State<DigestScreen> createState() => _DigestScreenState();
}

class _DigestScreenState extends State<DigestScreen> {
  String? _expandedCategory;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final int urgentCount = state.urgentNotifications.length;
        final int normalCount = state.importantNotifications.length;
        final int noisyCount = state.noisyNotifications.length;
        final int totalNotifs = state.notifications.length;

        final bool isSurge = state.isSurgeActive;
        final String llmHighlight = state.llmHighlight;
        final String llmDigest = state.llmDigest;
        final List<String> llmActionItems = state.llmActionItems;
        final DateTime? llmTimestamp = state.llmTimestamp;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pulse Digest',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Intelligent Notification Management',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.white30,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Summarize Button
                      if (state.isSummarizing)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(LucideIcons.refreshCcw, color: Colors.white70, size: 18),
                          onPressed: () => state.manualRequestSummary(),
                          tooltip: 'Summarize Now',
                        ),
                      const SizedBox(width: 4),
                      // Live/stale indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isSurge 
                              ? Colors.red.withValues(alpha: 0.12)
                              : (urgentCount + normalCount > 0)
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSurge 
                                ? Colors.red.withValues(alpha: 0.4)
                                : (urgentCount + normalCount > 0)
                                  ? Colors.green.withValues(alpha: 0.4)
                                  : Colors.white12,
                          ),
                        ),
                        child: Text(
                          isSurge ? 'SURGE' : ( (urgentCount + normalCount > 0) ? 'ACTIVE' : 'WAITING'),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSurge ? Colors.red : ( (urgentCount + normalCount > 0) ? Colors.green : Colors.white30),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── AI Summary Card (PERSISTENT — never overwritten by heartbeat) ──
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isSurge ? Colors.redAccent : Colors.blueAccent)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSurge ? LucideIcons.zap : LucideIcons.sparkles,
                                size: 15,
                                color: isSurge ? Colors.redAccent : Colors.blueAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSurge ? 'SURGE — AI SUMMARY' : 'AI SUMMARY',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: isSurge ? Colors.redAccent : Colors.blueAccent,
                                    ),
                                  ),
                                  if (llmTimestamp != null)
                                    Text(
                                      'Last updated ${_formatTime(llmTimestamp)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        color: Colors.white24,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Summarize button
                            if (state.isSummarizing)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.blueAccent),
                              )
                            else
                              GestureDetector(
                                onTap: () => state.manualRequestSummary(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.blueAccent.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.refreshCcw,
                                          size: 12, color: Colors.blueAccent),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Summarize',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: Colors.blueAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (llmHighlight.isEmpty && llmDigest.isEmpty)
                          Text(
                            totalNotifs == 0
                                ? 'No notifications yet. Run the simulation to get started.'
                                : 'Press Summarize to generate an AI summary of your $totalNotifs notification${totalNotifs == 1 ? '' : 's'}.',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.white38,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else ...[  
                          if (llmHighlight.isNotEmpty) ...[  
                            Text(
                              llmHighlight,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                          ],
                          // Action bullets — short, scannable, one per important notif
                          if (llmActionItems.isNotEmpty) ...[  
                            const SizedBox(height: 14),
                            ...llmActionItems.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(top: 5, right: 10),
                                    decoration: BoxDecoration(
                                      color: isSurge ? Colors.redAccent : Colors.blueAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                          // Digest paragraph — noise summary
                          if (llmDigest.isNotEmpty) ...[  
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06)),
                              ),
                              child: Text(
                                llmDigest,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  height: 1.5,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Notification count debug row
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '$totalNotifs notification${totalNotifs == 1 ? '' : 's'} captured  •  $urgentCount urgent  •  $normalCount important  •  $noisyCount noisy',
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: Colors.white24),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Important (formerly Urgent)
                  _buildExpandableSection(
                    title: 'Important',
                    count: urgentCount,
                    color: AppColors.urgent,
                    icon: LucideIcons.alertCircle,
                    items: state.urgentNotifications,
                    isExpanded: _expandedCategory == 'Important',
                    onToggle: () => _toggleCategory('Important'),
                  ),
                  const SizedBox(height: 14),

                  // Normal (formerly Important)
                  _buildExpandableSection(
                    title: 'Normal',
                    count: normalCount,
                    color: AppColors.important,
                    icon: LucideIcons.messageCircle,
                    items: state.importantNotifications,
                    isExpanded: _expandedCategory == 'Normal',
                    onToggle: () => _toggleCategory('Normal'),
                  ),
                  const SizedBox(height: 14),

                  // Noisy
                  _buildExpandableSection(
                    title: 'Noisy',
                    count: noisyCount,
                    color: Colors.white24,
                    icon: LucideIcons.bellOff,
                    items: state.noisyNotifications,
                    isExpanded: _expandedCategory == 'Noisy',
                    onToggle: () => _toggleCategory('Noisy'),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_expandedCategory == category) {
        _expandedCategory = null;
      } else {
        _expandedCategory = category;
      }
    });
  }

  Widget _buildExpandableSection({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required List<NotificationInfo> items,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$title ($count)',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        count == 0 ? 'No notifications' : 'Tap to ${isExpanded ? 'close' : 'open'}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  color: Colors.white12,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: items.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 5, right: 12),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${n.appName}: ${n.title}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              n.text,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )).toList().cast<Widget>(),
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
