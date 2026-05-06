import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';

class RouteDetailBottomSheet extends StatelessWidget {
  final AppointmentEtaInfo eta;

  const RouteDetailBottomSheet({super.key, required this.eta});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Route to destination",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white30,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    eta.eventTitle ?? "Appointment",
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              _buildCloseButton(context),
            ],
          ),
          const SizedBox(height: 32),
          _buildSchematicRoute(),
          const SizedBox(height: 32),
          _buildDetailRow(
            LucideIcons.navigation,
            "Distance: ${(eta.distanceMeters ?? 0) / 1000} km · ${eta.etaDisplay}",
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            LucideIcons.clock,
            "Leave by: ${_formatLeaveBy()} to arrive ${_formatEventTime()}",
          ),
          const SizedBox(height: 16),
          if (eta.worstSegment != null)
            _buildDetailRow(
              LucideIcons.alertTriangle,
              "Worst segment: ${eta.worstSegment!['delayMinutes']} min delay on ${eta.worstSegment!['name']}",
              color: Colors.orangeAccent,
            ),
          const SizedBox(height: 40),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.x, size: 20, color: Colors.white),
      ),
    );
  }

  Widget _buildSchematicRoute() {
    return Container(
      height: 120,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _routeNode(LucideIcons.home, "Origin"),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    Colors.orangeAccent,
                    AppColors.primary,
                  ],
                ),
              ),
            ),
          ),
          _routeNode(LucideIcons.mapPin, "Dest"),
        ],
      ),
    );
  }

  Widget _routeNode(IconData icon, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 24, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, color: Colors.white30),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? Colors.white30),
        const SizedBox(width: 16),
        Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: color ?? Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              "Use this route",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            onPressed: () {
              // Open in Maps logic would go here
              Navigator.pop(context);
            },
            icon: const Icon(LucideIcons.externalLink, color: Colors.white),
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  String _formatLeaveBy() {
    if (eta.leaveInMinutes == null) return "Now";
    final now = DateTime.now();
    final leaveTime = now.add(Duration(minutes: eta.leaveInMinutes!));
    return "${leaveTime.hour.toString().padLeft(2, '0')}:${leaveTime.minute.toString().padLeft(2, '0')}";
  }

  String _formatEventTime() {
    if (eta.eventTime == null) return "on time";
    final t = DateTime.parse(eta.eventTime!);
    return "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
  }
}
