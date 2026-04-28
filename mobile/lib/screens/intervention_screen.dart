import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';

class InterventionScreen extends StatelessWidget {
  const InterventionScreen({super.key});

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
              const Text("Suggested action right now", style: TextStyle(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildPrimaryActionCard(),
              const SizedBox(height: 32),
              _buildActionCategory("Commute", [
                _actionRow(LucideIcons.car, "Switch to cab", "Saves 15 min vs Metro walking", true),
                _actionRow(LucideIcons.batteryCharging, "Add charging stop", "Ensures +20% buffer for lab", false),
              ]),
              const SizedBox(height: 24),
              _buildActionCategory("Focus", [
                _actionRow(LucideIcons.moon, "Commute mode", "Auto-reply to all non-urgent", true),
                _actionRow(LucideIcons.bellOff, "Suppress noisy senders", "Cuts notification load by ~40%", false),
              ]),
              const SizedBox(height: 24),
              _buildActionCategory("Communication", [
                _actionRow(LucideIcons.messageCircle, "Send 'Running late'", "Notifies client review host", false),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryActionCard() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(LucideIcons.zap, color: Colors.greenAccent, size: 20),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text("Leave now and take Metro + cab", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text("Reduces lateness risk from 0.78 → 0.23.", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text("Accept", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text("Alternatives"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCategory(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _actionRow(IconData icon, String title, String impact, bool isEnabled) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Row(
        children: [
          Icon(icon, color: Colors.white30, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(impact, style: const TextStyle(color: Colors.white30, fontSize: 11)),
              ],
            ),
          ),
          Switch(value: isEnabled, onChanged: (v) {}, activeColor: AppColors.primary),
        ],
      ),
    );
  }
}
