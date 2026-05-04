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

        final isAtRisk =
            eta.latenessRisk == 'at_risk' || eta.latenessRisk == 'HIGH';
        final color = isAtRisk ? AppColors.danger : AppColors.primary;

        return GestureDetector(
          onTap: () => _showRouteDetails(context, state),
          child: Container(
            margin: isMini
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(vertical: 4),
            child: GlassCard(
              padding: EdgeInsets.all(isMini ? 12 : 16),
              borderColor: color.withValues(alpha: 0.2),
              child: Row(
                children: [
                  _buildModeIcon(eta.travelMode, color),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                eta.eventTitle ?? "Next Event",
                                style: GoogleFonts.outfit(
                                  fontSize: isMini ? 12 : 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAtRisk) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "AT RISK",
                                  style: GoogleFonts.outfit(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.mapPin,
                              size: 10,
                              color: Colors.white30,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                eta.destinationName ?? "Destination",
                                style: GoogleFonts.outfit(
                                  fontSize: isMini ? 10 : 12,
                                  color: Colors.white60,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildEtaPill(eta, color),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeIcon(String? mode, Color color) {
    IconData icon;
    switch (mode?.toLowerCase()) {
      case 'metro':
      case 'train':
        icon = LucideIcons.train;
        break;
      case 'bus':
        icon = LucideIcons.bus;
        break;
      case 'walking':
        icon = LucideIcons.footprints;
        break;
      case 'cycling':
      case 'bicycle':
        icon = LucideIcons.bike;
        break;
      default:
        icon = LucideIcons.car;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildEtaPill(AppointmentEtaInfo eta, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            eta.etaDisplay ?? "-- min",
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            eta.leaveInMinutes != null && eta.leaveInMinutes! <= 0
                ? "LEAVE NOW"
                : "IN ${eta.etaDisplay?.toUpperCase() ?? '-- MIN'}",
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showRouteDetails(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      builder: (context) => RouteDetailBottomSheet(eta: state.etaInfo),
    );
  }

  Widget _buildFallbackStrip(BuildContext context, String message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: Colors.white10,
        child: Row(
          children: [
            const Icon(LucideIcons.map, size: 18, color: Colors.white24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.white30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
