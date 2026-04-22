import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/app_state.dart';
import '../models/intervention.dart';
import '../widgets/glass_card.dart';
import '../theme/colors.dart';

class InterventionScreen extends StatelessWidget {
  const InterventionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final intervention = state.interventions.isNotEmpty ? state.interventions.first : null;
        
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: AppColors.surfaceGradient,
            ),
            child: SafeArea(
              child: intervention == null 
                ? _buildEmptyState(context)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 24),
                        _buildMainCard(context, intervention),
                        const SizedBox(height: 20),
                        _buildReasonBox(context, intervention),
                        const SizedBox(height: 20),
                        _buildStepsBox(context, intervention),
                        const SizedBox(height: 20),
                        _buildImpactBox(context, intervention),
                        const SizedBox(height: 32),
                        _buildActionButtons(context, state, intervention),
                        const SizedBox(height: 20),
                        _buildTraceabilityBox(context, intervention),
                      ],
                    ),
                  ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.shieldCheck, size: 80, color: AppColors.primary.withOpacity(0.2)),
          const SizedBox(height: 24),
          Text("No Active Interventions", style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text("You're all set! We'll notify you if needed.", style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Suggested Action", style: Theme.of(context).textTheme.headlineMedium),
        Text("Mitigate risk with these steps", style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildMainCard(BuildContext context, Intervention intervention) {
    return GlassCard(
      borderColor: AppColors.secondary.withOpacity(0.4),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.zap, color: AppColors.secondary),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(intervention.title, style: Theme.of(context).textTheme.titleLarge),
                Text(intervention.type, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text("URGENT", style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonBox(BuildContext context, Intervention intervention) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Why this action?", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(intervention.reason, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildStepsBox(BuildContext context, Intervention intervention) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Action Steps", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ...intervention.steps.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${entry.key + 1}.", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(child: Text(entry.value, style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildImpactBox(BuildContext context, Intervention intervention) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.trendingDown, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Expected Impact: ${intervention.impact}",
              style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppState state, Intervention intervention) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: () => state.updateInterventionStatus(intervention.id, InterventionStatus.done),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
              shadowColor: AppColors.primary.withOpacity(0.5),
            ),
            child: const Text("MARK AS DONE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(
                context, 
                "SNOOZE", 
                LucideIcons.clock, 
                () => state.updateInterventionStatus(intervention.id, InterventionStatus.snoozed),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryButton(
                context, 
                "DISMISS", 
                LucideIcons.x, 
                () => state.updateInterventionStatus(intervention.id, InterventionStatus.dismissed),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryButton(BuildContext context, String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        foregroundColor: AppColors.textPrimary,
        side: BorderSide(color: AppColors.textMuted.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildTraceabilityBox(BuildContext context, Intervention intervention) {
    return Center(
      child: Text(
        "ID: ${intervention.id} • Source: Planner v1.2",
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}
