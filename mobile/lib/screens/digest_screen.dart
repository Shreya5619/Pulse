import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';

class DigestScreen extends StatelessWidget {
  const DigestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Notification digest",
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Last 60 min",
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white30),
              ),
              const SizedBox(height: 32),
              _buildDigestCard(
                context,
                title: "Urgent (2)",
                summary: "May affect today's schedule.",
                details:
                    "Client Review host: 'Can we move to 10:15?'\nBattery Alert: Power bank not detected.",
                color: Colors.redAccent,
                icon: LucideIcons.alertCircle,
              ),
              const SizedBox(height: 16),
              _buildDigestCard(
                context,
                title: "Important (7)",
                summary: "Could be handled by end of day.",
                details:
                    "7 Slack messages across 3 channels.\nMostly project updates and feedback.",
                color: Colors.orangeAccent,
                icon: LucideIcons.messageCircle,
              ),
              const SizedBox(height: 16),
              _buildDigestCard(
                context,
                title: "Noisy / Ignorable (41)",
                summary: "Muted for next 60 min in commute mode.",
                details:
                    "Email promos, social media pings, and news alerts.\nAutomatically archived by Pulse.",
                color: Colors.white24,
                icon: LucideIcons.bellOff,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigestCard(
    BuildContext context, {
    required String title,
    required String summary,
    required String details,
    required Color color,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => _showDetails(context, title, details, color),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: Colors.white10,
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
            const SizedBox(height: 24),
            Text(
              details,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "Mark done",
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
                      vertical: 16,
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
