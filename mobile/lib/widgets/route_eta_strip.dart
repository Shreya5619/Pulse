import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import 'glass_card.dart';
import 'route_detail_bottom_sheet.dart';

class RouteEtaStrip extends StatelessWidget {
  final bool isMini;

  const RouteEtaStrip({super.key, this.isMini = false});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final eta = state.etaInfo;

        if (!eta.hasRoute) {
          if (isMini) return const SizedBox.shrink();
          return _buildFallbackStrip(
            context,
            eta.reason ?? "No travel detected",
          );
        }

        return GestureDetector(
          onTap: () => _showRouteDetails(context, state),
          child: GlassCard(
            padding: EdgeInsets.all(isMini ? 12 : 16),
            borderColor: eta.latenessRisk == 'at_risk'
                ? AppColors.danger.withValues(alpha: 0.3)
                : AppColors.primary.withValues(alpha: 0.1),
            child: Row(
              children: [
                _buildModeIcon(eta.travelMode),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Next: ${eta.eventTitle}",
                        style: GoogleFonts.outfit(
                          fontSize: isMini ? 11 : 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${eta.destinationName} · ${eta.etaDisplay}",
                        style: GoogleFonts.outfit(
                          fontSize: isMini ? 9 : 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildEtaPill(eta),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeIcon(String? mode) {
    IconData icon;
    switch (mode) {
      case 'metro':
        icon = LucideIcons.train;
        break;
      case 'walking':
        icon = LucideIcons.footprints;
        break;
      default:
        icon = LucideIcons.car;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: AppColors.primary),
    );
  }

  Widget _buildEtaPill(AppointmentEtaInfo eta) {
    final isAtRisk = eta.latenessRisk == 'at_risk';
    final color = isAtRisk ? AppColors.danger : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "ETA ${eta.etaDisplay}",
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (eta.leaveInMinutes != null)
            Text(
              eta.leaveInMinutes! <= 0
                  ? "Leave now"
                  : "Leave in ${eta.leaveInMinutes}m",
              style: GoogleFonts.outfit(
                fontSize: 8,
                color: color.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallbackStrip(BuildContext context, String message) {
    String displayMessage = message;
    if (message == "No context") displayMessage = "Searching for context...";
    if (message == "No event")
      displayMessage = "No travel needed in next 2 hours.";
    if (message == "No event location")
      displayMessage = "Add location to next event to see ETA.";

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(LucideIcons.mapPin, size: 14, color: Colors.white24),
          const SizedBox(width: 12),
          Text(
            displayMessage,
            style: GoogleFonts.outfit(fontSize: 11, color: Colors.white30),
          ),
          const Spacer(),
          if (message == "No event location")
            const Icon(LucideIcons.plus, size: 12, color: AppColors.primary),
        ],
      ),
    );
  }

  void _showRouteDetails(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RouteDetailBottomSheet(eta: state.etaInfo),
    );
  }
}
