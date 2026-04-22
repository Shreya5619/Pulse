import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/app_state.dart';
import '../widgets/glass_card.dart';
import '../theme/colors.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int? _selectedRating;
  String? _selectedOutcome;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: AppColors.surfaceGradient,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 32),
                    _buildFeedbackForm(context),
                    const SizedBox(height: 24),
                    _buildOutcomeSection(context),
                    const SizedBox(height: 24),
                    _buildNotesSection(context),
                    const SizedBox(height: 32),
                    _buildSubmitButton(context),
                    const SizedBox(height: 40),
                    _buildHistorySection(context, state),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Feedback & History", style: Theme.of(context).textTheme.headlineMedium),
        Text("Help us improve your risk model", style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildFeedbackForm(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text("Was the recent intervention helpful?", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [1, 2, 3, 4, 5].map((i) => GestureDetector(
              onTap: () => setState(() => _selectedRating = i),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _selectedRating == i ? AppColors.primary : AppColors.surfaceVariant,
                  border: Border.all(color: _selectedRating == i ? AppColors.primary : AppColors.textMuted.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    i.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selectedRating == i ? Colors.black : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeSection(BuildContext context) {
    final outcomes = ["Safe now", "Still stressed", "False alarm"];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Current Status", style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: outcomes.map((o) => ChoiceChip(
            label: Text(o),
            selected: _selectedOutcome == o,
            onSelected: (selected) => setState(() => _selectedOutcome = selected ? o : null),
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.primary.withOpacity(0.2),
            labelStyle: TextStyle(color: _selectedOutcome == o ? AppColors.primary : AppColors.textSecondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    return TextField(
      maxLines: 3,
      decoration: InputDecoration(
        hintText: "Add optional notes...",
        filled: true,
        fillColor: AppColors.surface.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.textMuted.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.textMuted.withOpacity(0.3)),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceVariant,
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.primary)),
        ),
        child: const Text("SUBMIT FEEDBACK", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Recent History", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        ...state.interventions.map((i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(LucideIcons.history, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text(i.type, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                _buildStatusBadge(i.status),
              ],
            ),
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildStatusBadge(dynamic status) {
    Color color = AppColors.textMuted;
    String text = status.toString().split('.').last.toUpperCase();
    
    if (text == "DONE") color = AppColors.success;
    if (text == "PENDING") color = AppColors.warning;
    if (text == "DISMISSED") color = AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
