import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import '../widgets/action_cards.dart';

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
                      child: UnifiedActionCard(action: chosen, isHero: true),
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
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Pulse Planner's recommended interventions",
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white30),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedActions(
    BuildContext context,
    AppState state,
    List<dynamic> actions,
  ) {
    final commute = actions.where((a) => a['category'] == "Commute").toList();
    final focus = actions.where((a) => a['category'] == "Focus").toList();
    final comms = actions
        .where((a) => a['category'] == "Communication")
        .toList();
    final general = actions
        .where((a) => a['category'] == null || a['category'] == "General")
        .toList();

    return SliverList(
      delegate: SliverChildListDelegate([
        if (commute.isNotEmpty)
          _buildCategoryHeader("Commute", LucideIcons.car),
        ...commute.map((a) => UnifiedActionCard(action: a)),

        if (focus.isNotEmpty) _buildCategoryHeader("Focus", LucideIcons.brain),
        ...focus.map((a) => UnifiedActionCard(action: a)),

        if (comms.isNotEmpty)
          _buildCategoryHeader("Communication", LucideIcons.messageSquare),
        ...comms.map(
          (a) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: UnifiedActionCard(action: a),
          ),
        ),

        if (general.isNotEmpty)
          _buildCategoryHeader("Other", LucideIcons.moreHorizontal),
        ...general.map((a) => UnifiedActionCard(action: a)),
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
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.shieldCheck,
              size: 64,
              color: Colors.white10,
            ),
            const SizedBox(height: 24),
            Text(
              "No interventions needed",
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
}
