import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'dart:io';
import '../theme/colors.dart';
import '../widgets/glass_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_settings/app_settings.dart';
import 'package:android_intent_plus/android_intent.dart';

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
                if (state.proposedCommAction != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: CommActionCard(action: state.proposedCommAction!),
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

  Widget _buildHeroCard(BuildContext context, AppState state, dynamic action) {
    final isAccepted = state.isActionAccepted(action['id']);
    final isDismissed = state.isActionDismissed(action['id']);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: isAccepted
          ? AppColors.success.withValues(alpha: 0.5)
          : isDismissed
          ? Colors.white10
          : AppColors.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.zap,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "PRIMARY SUGGESTION",
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
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
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            action['impact'] ?? action['description'] ?? "",
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            action['description'] ?? "",
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.5,
            ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      "ACCEPT PLAN",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => state.dismissAction(action),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white30,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  child: const Text("Dismiss"),
                ),
              ],
            )
          else if (isAccepted)
            _buildStatusIndicator(
              LucideIcons.checkCircle2,
              "ACCEPTED",
              AppColors.success,
            )
          else
            _buildStatusIndicator(
              LucideIcons.xCircle,
              "DISMISSED",
              Colors.white24,
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
              letterSpacing: 1,
            ),
          ),
        ],
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
        ...commute.map((a) => _buildActionRow(context, state, a)),

        if (focus.isNotEmpty) _buildCategoryHeader("Focus", LucideIcons.brain),
        ...focus.map((a) => _buildActionRow(context, state, a)),

        if (comms.isNotEmpty)
          _buildCategoryHeader("Communication", LucideIcons.messageSquare),
        ...comms.map((a) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: CommActionCard(action: a),
            )),

        if (general.isNotEmpty)
          _buildCategoryHeader("Other", LucideIcons.moreHorizontal),
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
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, AppState state, dynamic action) {
    final String actionId = action['id'] ?? "";
    final isAccepted = state.isActionAccepted(actionId);
    final isDismissed = state.isActionDismissed(actionId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Opacity(
        opacity: isDismissed ? 0.4 : 1.0,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _getIconForAction(actionId),
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
                        color: isAccepted ? AppColors.success : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action['impact'] ?? "",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white30,
                      ),
                    ),
                    if (action['id'] == "ACTION_SUPPRESS_NOISY_NOTIFICATIONS" &&
                        action['metadata'] != null)
                      _buildNoisyAppsList(context, action['metadata']),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Approve",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                )
              else if (isAccepted)
                const Icon(
                  LucideIcons.check,
                  size: 16,
                  color: AppColors.success,
                )
              else
                IconButton(
                  icon: const Icon(
                    LucideIcons.rotateCcw,
                    size: 14,
                    color: Colors.white24,
                  ),
                  onPressed: () => state.acceptAction(action),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getIconForAction(String? id) {
    final String actionId = id ?? "";
    IconData iconData = LucideIcons.zap;
    Color color = AppColors.primary;

    if (actionId.contains("LEAVE")) {
      iconData = LucideIcons.car;
      color = Colors.blueAccent;
    } else if (actionId.contains("BATTERY")) {
      iconData = LucideIcons.battery;
      color = AppColors.warning;
    } else if (actionId.contains("NOTIFICATIONS")) {
      iconData = LucideIcons.bellOff;
      color = Colors.deepPurpleAccent;
    } else if (actionId.contains("MESSAGE")) {
      iconData = LucideIcons.messageSquare;
      color = AppColors.success;
    } else if (actionId.contains("CHARGING")) {
      iconData = LucideIcons.zap;
      color = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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

  void _handleAccept(BuildContext context, AppState state, dynamic action) {
    state.acceptAction(action);

    final id = action['id'] as String;
    String message = "Plan updated; Pulse will track ETA against this.";

    if (id.contains("NOTIFICATIONS")) {
      message = "Focus mode active. Opening notification settings...";
      state.openNotificationSettings();
    } else if (id.contains("BATTERY_SAVER")) {
      message = "Redirecting to Battery settings...";
      if (Platform.isAndroid) {
        const intent = AndroidIntent(
          action: 'android.settings.BATTERY_SAVER_SETTINGS',
        );
        intent.launch();
      } else {
        // Fallback for iOS or other platforms
        AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
      }
    } else if (id.contains("MESSAGE")) {
      _showDraftSheet(context, action);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDraftSheet(
    BuildContext context,
    dynamic action, {
    String? manualText,
  }) {
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
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                manualText ??
                    "Hey! Just letting you know I'm running about 10 minutes late due to traffic. Should be there shortly!",
                style: const TextStyle(
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Draft copied to clipboard and messaging app opened",
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "COPY & OPEN MESSAGING",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoisyAppsList(BuildContext context, dynamic metadata) {
    final List<dynamic> apps = metadata['noisyApps'] ?? [];
    if (apps.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "NOISY APPS DETECTED:",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white24,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          ...apps.map(
            (app) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      LucideIcons.bellOff,
                      size: 12,
                      color: Colors.white30,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app['name'] ?? "Unknown App",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          "${app['count']} notifications",
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white30,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        _openAppNotificationSettings(app['packageName']),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      "MUTE",
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () =>
                  Provider.of<AppState>(context, listen: false)
                      .openNotificationSettings(),
              icon: const Icon(LucideIcons.settings, size: 12),
              label: const Text(
                "OPEN GENERAL NOTIFICATION SETTINGS",
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAppNotificationSettings(String? packageName) {
    if (packageName == null) return;

    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'android.settings.APP_NOTIFICATION_SETTINGS',
        arguments: {
          'android.provider.extra.APP_PACKAGE': packageName,
          'app_package': packageName,
        },
      );
      intent.launch();
    } else {
      AppSettings.openAppSettings(type: AppSettingsType.notification);
    }
  }
}

class CommActionCard extends StatefulWidget {
  final Map<String, dynamic> action;
  const CommActionCard({super.key, required this.action});

  @override
  State<CommActionCard> createState() => _CommActionCardState();
}

class _CommActionCardState extends State<CommActionCard> {
  String _selectedRole = "General";
  String? _draftText;
  String? _recipient;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchDraft();
  }

  Future<void> _fetchDraft() async {
    setState(() {
      _isLoading = true;
      _draftText = null;
    });
    final state = Provider.of<AppState>(context, listen: false);
    final prepared = await state.prepareCommAction(
      widget.action['id'],
      role: _selectedRole,
    );
    if (prepared != null) {
      setState(() {
        _draftText = prepared['text'];
        _recipient = prepared['recipient'];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _handleSend(AppState state, {bool pickContact = false}) async {
    if (_draftText == null) return;

    final String recipientPath = pickContact ? "" : (_recipient ?? "");
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: recipientPath,
      queryParameters: <String, String>{'body': _draftText!},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
      state.completeCommAction(widget.action['id']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch messaging app")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final String actionId = widget.action['id'] ?? "";
    final isAccepted = state.isActionAccepted(actionId);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderColor: AppColors.success.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.messageCircle,
                    color: AppColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "SMART MESSAGE",
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              if (_isLoading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Drafting for:",
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.white30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ["General", "Manager", "Customer", "Family"].map((
                role,
              ) {
                final isSelected = _selectedRole == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      role,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedRole = role);
                        _fetchDraft();
                      }
                    },
                    selectedColor: AppColors.success,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "MESSAGE DRAFT",
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: Colors.white24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!_isLoading && _draftText != null)
                Row(
                  children: [
                    const Icon(
                      LucideIcons.sparkles,
                      size: 10,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "AI POLISHED",
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              _draftText ?? (widget.action['previewText'] ?? "Drafting..."),
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!isAccepted)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleSend(state),
                    icon: const Icon(LucideIcons.send, size: 14),
                    label: Text("SEND TO ${_selectedRole.toUpperCase()}"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _handleSend(state, pickContact: true),
                  icon: const Icon(LucideIcons.userPlus, color: Colors.white30),
                  tooltip: "Select different contact",
                ),
              ],
            )
          else
            _buildStatusIndicator(
              LucideIcons.checkCircle2,
              "SENT",
              AppColors.success,
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
