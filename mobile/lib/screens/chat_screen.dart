import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Ask Pulse",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings2, color: Colors.white70, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                if (appState.chatMessages.isEmpty) {
                  return _buildEmptyState();
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: appState.chatMessages.length + (appState.isChatLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == appState.chatMessages.length) {
                      return _buildLoadingIndicator();
                    }
                    final msg = appState.chatMessages[index];
                    return _buildChatBubble(msg);
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.sparkles, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            "Hello, I'm Pulse",
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "I'm your digital twin. Ask me about your\nrisks, day plan, or to take an action.",
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 40),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      "Why is my risk high?",
      "What if I leave 15m later?",
      "Mute social notifications",
      "I prefer studying late"
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: actions.map((a) => _buildQuickActionButton(a)).toList(),
    );
  }

  Widget _buildQuickActionButton(String text) {
    return GestureDetector(
      onTap: () {
        _controller.text = text;
        _handleSend();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!msg.isUser && msg.toolsUsed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Wrap(
                spacing: 6,
                children: msg.toolsUsed.map((t) => _buildToolBadge(t)).toList(),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: msg.isUser ? AppColors.primary : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(msg.isUser ? 20 : 4),
                bottomRight: Radius.circular(msg.isUser ? 4 : 20),
              ),
            ),
            child: Text(
              msg.text,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          if (msg.actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                children: msg.actions.map((a) => _buildActionCard(a)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolBadge(String tool) {
    String label = tool;
    IconData icon = LucideIcons.wrench;
    
    if (tool == 'getCurrentRisks') { label = "checked risks"; icon = LucideIcons.shieldAlert; }
    if (tool == 'getDailyPulse') { label = "analyzed day"; icon = LucideIcons.calendar; }
    if (tool == 'simulateWhatIf') { label = "ran futures"; icon = LucideIcons.trendingUp; }
    if (tool == 'getNotificationSummary') { label = "read alerts"; icon = LucideIcons.layout; }
    if (tool == 'getGuardianActions') { label = "found solutions"; icon = LucideIcons.zap; }
    if (tool == 'updateTwinGraph') { label = "learned preference"; icon = LucideIcons.brainCircuit; }
    if (tool == 'addDailyEvent') { label = "updated schedule"; icon = LucideIcons.plusCircle; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(Map<String, dynamic> action) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            action['title'] ?? 'Action',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              Provider.of<AppState>(context, listen: false).acceptAction({
                'id': action['id'],
                'title': action['title'],
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Action confirmed: ${action['title']}")),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                "Confirm",
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Pulse is thinking...",
                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: GoogleFonts.outfit(color: Colors.white38),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.send, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSend() {
    if (_controller.text.trim().isEmpty) return;
    Provider.of<AppState>(context, listen: false).sendChatMessage(_controller.text);
    _controller.clear();
    _scrollToBottom();
  }
}
