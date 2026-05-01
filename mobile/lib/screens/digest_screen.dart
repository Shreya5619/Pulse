import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';
import '../providers/app_state.dart';

class DigestScreen extends StatelessWidget {
  const DigestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final snap = state.pulseSnapshot;
        final digest = snap['notificationDigest'] as Map<String, dynamic>?;

        final List<String> urgent = List<String>.from(
          digest?['urgent'] as List? ?? [],
        );
        final List<String> important = List<String>.from(
          digest?['important'] as List? ?? [],
        );
        final int noiseCount = (digest?['noiseCount'] as num?)?.toInt() ?? 0;
        final String highlight =
            digest?['highlight'] as String? ?? '0 notifications';

        // Determine if we have live data or are showing the placeholder
        final bool hasLiveData =
            digest != null &&
            (urgent.isNotEmpty || important.isNotEmpty || noiseCount > 0);

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
                              'Notification Digest',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Last heartbeat cycle',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.white30,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Live/stale indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: hasLiveData
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasLiveData
                                ? Colors.green.withValues(alpha: 0.4)
                                : Colors.white12,
                          ),
                        ),
                        child: Text(
                          hasLiveData ? 'LIVE' : 'NO DATA',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: hasLiveData ? Colors.green : Colors.white30,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Highlight summary pill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.bell,
                          size: 14,
                          color: Colors.white38,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          highlight,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Urgent
                  _buildDigestCard(
                    context,
                    title: 'Urgent (${urgent.length})',
                    summary: urgent.isEmpty
                        ? 'No urgent notifications'
                        : 'Requires immediate attention.',
                    details: urgent.isEmpty
                        ? 'No urgent items in this cycle.'
                        : urgent.join('\n'),
                    color: const Color(0xFFFF4444),
                    icon: LucideIcons.alertCircle,
                    items: urgent,
                  ),
                  const SizedBox(height: 14),

                  // Important
                  _buildDigestCard(
                    context,
                    title: 'Important (${important.length})',
                    summary: important.isEmpty
                        ? 'No important notifications'
                        : 'Could be handled later today.',
                    details: important.isEmpty
                        ? 'No important items in this cycle.'
                        : important.join('\n'),
                    color: const Color(0xFFFFB830),
                    icon: LucideIcons.messageCircle,
                    items: important,
                  ),
                  const SizedBox(height: 14),

                  // Noisy / Ignorable
                  _buildDigestCard(
                    context,
                    title: 'Noisy / Ignorable ($noiseCount)',
                    summary: noiseCount == 0
                        ? 'No noise detected'
                        : 'Muted automatically by Pulse.',
                    details: noiseCount == 0
                        ? 'Nothing was filtered this cycle.'
                        : '$noiseCount low-signal notifications were suppressed.\nPromos, social pings, and news alerts.',
                    color: Colors.white24,
                    icon: LucideIcons.bellOff,
                    items: const [],
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

  Widget _buildDigestCard(
    BuildContext context, {
    required String title,
    required String summary,
    required String details,
    required Color color,
    required IconData icon,
    required List<String> items,
  }) {
    return GestureDetector(
      onTap: () => _showDetails(context, title, details, color, items),
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
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    summary,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: Colors.white12,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    String title,
    String details,
    Color color,
    List<String> items,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1426),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white30),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isNotEmpty)
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 10, top: 1),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                details,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Mark done',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  child: const Icon(LucideIcons.bellOff, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
