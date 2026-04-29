import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';

class InterventionScreen extends StatelessWidget {
  const InterventionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final decision = state.lastPlannerDecision;
        final chosen = decision?['chosen'];
        final alternatives = decision?['alternatives'] as List<dynamic>? ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                _buildHeader(context),
                if (chosen != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildHeroCard(context, state, chosen),
                    ),
                  ),
                if (chosen == null && alternatives.isEmpty)
                  _buildEmptyState()
                else
                  _buildGroupedActions(context, state, alternatives),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Guardian Actions",
              style: GoogleFonts.outfit(
                fontSize: 28, 
                fontWeight: FontWeight.bold, 
                color: Colors.white
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Pulse Planner's recommended interventions",
              style: GoogleFonts.outfit(
                fontSize: 14, 
                color: Colors.white30
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, AppState state, dynamic action) {
    final isAccepted = state.isActionAccepted(action['id']);
    final isDismissed = state.isActionDismissed(action['id']);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: isAccepted 
          ? AppColors.success.withOpacity(0.5) 
          : isDismissed 
              ? Colors.white10 
              : AppColors.primary.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.zap, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                "PRIMARY SUGGESTION",
                style: GoogleFonts.outfit(
                  fontSize: 10, 
                  fontWeight: FontWeight.bold, 
                  color: AppColors.primary,
                  letterSpacing: 1.2
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            action['title'] ?? "Action",
            style: GoogleFonts.outfit(
              fontSize: 20, 
              fontWeight: FontWeight.bold, 
              color: Colors.white
            ),
          ),
          const SizedBox(height: 8),
          Text(
            action['impact'] ?? action['description'] ?? "",
            style: GoogleFonts.outfit(
              fontSize: 14, 
              color: AppColors.success,
              fontWeight: FontWeight.w500
            ),
          ),
          const SizedBox(height: 12),
          Text(
            action['description'] ?? "",
            style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          if (!isAccepted && !isDismissed)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAccept(context, state, action),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("ACCEPT PLAN", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => state.dismissAction(action),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white30,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  child: const Text("Dismiss"),
                ),
              ],
            )
          else if (isAccepted)
            _buildStatusIndicator(LucideIcons.checkCircle2, "ACCEPTED", AppColors.success)
          else
            _buildStatusIndicator(LucideIcons.xCircle, "DISMISSED", Colors.white24),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12, 
              fontWeight: FontWeight.bold, 
              color: color,
              letterSpacing: 1
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedActions(BuildContext context, AppState state, List<dynamic> actions) {
    final commute = actions.where((a) => a['category'] == "Commute").toList();
    final focus = actions.where((a) => a['category'] == "Focus").toList();
    final comms = actions.where((a) => a['category'] == "Communication").toList();
    final general = actions.where((a) => a['category'] == null || a['category'] == "General").toList();

    return SliverList(
      delegate: SliverChildListDelegate([
        if (commute.isNotEmpty) _buildCategoryHeader("Commute", LucideIcons.car),
        ...commute.map((a) => _buildActionRow(context, state, a)),
        
        if (focus.isNotEmpty) _buildCategoryHeader("Focus", LucideIcons.brain),
        ...focus.map((a) => _buildActionRow(context, state, a)),
        
        if (comms.isNotEmpty) _buildCategoryHeader("Communication", LucideIcons.messageSquare),
        ...comms.map((a) => _buildActionRow(context, state, a)),
        
        if (general.isNotEmpty) _buildCategoryHeader("Other", LucideIcons.moreHorizontal),
        ...general.map((a) => _buildActionRow(context, state, a)),
      ]),
    );
  }

  Widget _buildCategoryHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white24),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 11, 
              fontWeight: FontWeight.bold, 
              color: Colors.white24,
              letterSpacing: 1.2
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, AppState state, dynamic action) {
    final isAccepted = state.isActionAccepted(action['id']);
    final isDismissed = state.isActionDismissed(action['id']);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Opacity(
        opacity: isDismissed ? 0.4 : 1.0,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _getIconForAction(action['id']),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action['title'] ?? "",
                      style: GoogleFonts.outfit(
                        fontSize: 14, 
                        fontWeight: FontWeight.w600, 
                        color: isAccepted ? AppColors.success : Colors.white
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action['impact'] ?? "",
                      style: const TextStyle(fontSize: 11, color: Colors.white30),
                    ),
                  ],
                ),
              ),
              if (!isAccepted && !isDismissed)
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () => _handleAccept(context, state, action),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Approve", style: TextStyle(fontSize: 12)),
                  ),
                )
              else if (isAccepted)
                const Icon(LucideIcons.check, size: 16, color: AppColors.success)
              else
                IconButton(
                  icon: const Icon(LucideIcons.rotateCcw, size: 14, color: Colors.white24),
                  onPressed: () => state.acceptAction(action),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getIconForAction(String id) {
    IconData iconData = LucideIcons.zap;
    Color color = AppColors.primary;

    if (id.contains("LEAVE")) {
      iconData = LucideIcons.car;
      color = Colors.blueAccent;
    } else if (id.contains("BATTERY")) {
      iconData = LucideIcons.battery;
      color = AppColors.warning;
    } else if (id.contains("NOTIFICATIONS")) {
      iconData = LucideIcons.bellOff;
      color = Colors.deepPurpleAccent;
    } else if (id.contains("MESSAGE")) {
      iconData = LucideIcons.messageSquare;
      color = AppColors.success;
    } else if (id.contains("CHARGING")) {
      iconData = LucideIcons.zap;
      color = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: color, size: 18),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.shieldCheck, size: 64, color: Colors.white10),
            const SizedBox(height: 24),
            Text(
              "No interventions needed",
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              "You're currently on track with all your goals.",
              style: TextStyle(color: Colors.white30),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAccept(BuildContext context, AppState state, dynamic action) {
    state.acceptAction(action);
    
    final id = action['id'] as String;
    String message = "Plan updated; Pulse will track ETA against this.";
    
    if (id.contains("NOTIFICATIONS")) {
      message = "Noisy senders muted for 60 minutes.";
    } else if (id.contains("MESSAGE")) {
      _showDraftSheet(context, action);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDraftSheet(BuildContext context, dynamic action) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Drafting Message",
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                "Hey! Just letting you know I'm running about 10 minutes late due to traffic. Should be there shortly!",
                style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Draft copied to clipboard and messaging app opened")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("COPY & OPEN MESSAGING", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
