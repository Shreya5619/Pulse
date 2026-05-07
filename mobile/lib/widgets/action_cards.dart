import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:app_settings/app_settings.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import 'glass_card.dart';
import '../services/action_executor.dart';

class UnifiedActionCard extends StatelessWidget {
  final Map<String, dynamic> action;
  final bool isHero;

  const UnifiedActionCard({
    super.key,
    required this.action,
    this.isHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final String actionId = action['id'] ?? "";
    
    if (actionId.contains("MESSAGE") || action['category'] == "Communication") {
      return CommActionCard(action: action);
    }

    final isAccepted = state.isActionAccepted(actionId);
    final isDismissed = state.isActionDismissed(actionId);

    if (isHero) {
      return _buildHeroCard(context, state, isAccepted, isDismissed);
    }

    return Opacity(
      opacity: isDismissed ? 0.4 : 1.0,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
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
                        action['impact'] ?? action['description'] ?? "",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white30,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isAccepted && !isDismissed)
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () => ActionExecutor.execute(context, state, action),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
            if (actionId == "ACTION_SUPPRESS_NOISY_NOTIFICATIONS" && action['metadata'] != null)
              _buildNoisyAppsList(context, state, action['metadata']),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, AppState state, bool isAccepted, bool isDismissed) {
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
                child: const Icon(LucideIcons.zap, color: AppColors.primary, size: 20),
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
            style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          if (!isAccepted && !isDismissed)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ActionExecutor.execute(context, state, action),
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
                  style: TextButton.styleFrom(foregroundColor: Colors.white30),
                  child: const Text("Dismiss"),
                ),
              ],
            )
          else
            _StatusIndicator(
              icon: isAccepted ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
              text: isAccepted ? "ACCEPTED" : "DISMISSED",
              color: isAccepted ? AppColors.success : Colors.white24,
            ),
        ],
      ),
    );
  }

  Widget _getIconForAction(String actionId) {
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

  Widget _buildNoisyAppsList(BuildContext context, AppState state, dynamic metadata) {
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
                    child: const Icon(LucideIcons.bellOff, size: 12, color: Colors.white30),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app['name'] ?? "Unknown App",
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                        Text(
                          "${app['count']} notifications",
                          style: const TextStyle(fontSize: 9, color: Colors.white30),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openAppNotificationSettings(app['packageName']),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      "MUTE",
                      style: TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.bold),
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
              onPressed: () => state.openNotificationSettings(),
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

class _StatusIndicator extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusIndicator({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
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
    setState(() { _isLoading = true; _draftText = null; });
    final state = Provider.of<AppState>(context, listen: false);
    final prepared = await state.prepareCommAction(widget.action['id'], role: _selectedRole);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch messaging app")));
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
                  const Icon(LucideIcons.messageCircle, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "SMART MESSAGE",
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success, letterSpacing: 1.2),
                  ),
                ],
              ),
              if (_isLoading) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 16),
          Text("Drafting for:", style: GoogleFonts.outfit(fontSize: 12, color: Colors.white30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ["General", "Manager", "Customer", "Family"].map((role) {
                final isSelected = _selectedRole == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(role, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white70)),
                    selected: isSelected,
                    onSelected: (val) { if (val) { setState(() => _selectedRole = role); _fetchDraft(); } },
                    selectedColor: AppColors.success,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
            child: Text(_draftText ?? "Drafting...", style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70, fontStyle: FontStyle.italic)),
          ),
          const SizedBox(height: 20),
          if (!isAccepted)
            ElevatedButton.icon(
              onPressed: () => _handleSend(state),
              icon: const Icon(LucideIcons.send, size: 14),
              label: Text("SEND TO ${_selectedRole.toUpperCase()}"),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            )
          else
            _StatusIndicator(icon: LucideIcons.checkCircle2, text: "SENT", color: AppColors.success),
        ],
      ),
    );
  }
}
