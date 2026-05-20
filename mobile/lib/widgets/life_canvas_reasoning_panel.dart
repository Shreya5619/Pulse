import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AgentStep {
  final int id;
  final String type; // thinking | command | cypher | result | final | error
  final String title;
  final String detail;
  final String? cmd;
  final DateTime time;

  AgentStep({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    this.cmd,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class LifeCanvasReasoningPanel extends StatefulWidget {
  final List<AgentStep> steps;
  final bool isActive;
  final String statusText;
  /// When true (e.g. right rail), fill vertical space instead of a fixed 270px panel.
  final bool expandVertically;

  const LifeCanvasReasoningPanel({
    super.key,
    required this.steps,
    required this.isActive,
    required this.statusText,
    this.expandVertically = false,
  });

  @override
  State<LifeCanvasReasoningPanel> createState() => _LifeCanvasReasoningPanelState();
}

class _LifeCanvasReasoningPanelState extends State<LifeCanvasReasoningPanel>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant LifeCanvasReasoningPanel old) {
    super.didUpdateWidget(old);
    if (widget.steps.length != old.steps.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  IconData _icon(String type) {
    switch (type) {
      case 'command': return LucideIcons.terminal;
      case 'cypher': return LucideIcons.search;
      case 'result': return LucideIcons.zap;
      case 'final': return LucideIcons.checkCircle;
      case 'error': return LucideIcons.alertCircle;
      default: return LucideIcons.brain;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'command': return const Color(0xFF0A84FF);
      case 'cypher': return const Color(0xFF64D2FF);
      case 'result': return const Color(0xFF4EE2C9);
      case 'final': return const Color(0xFF4EE2C9);
      case 'error': return const Color(0xFFFF5252);
      default: return const Color(0xFFBF5AF2);
    }
  }

  String _timeLabel(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final shell = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07091A),
        border: Border(
          left: widget.expandVertically ? BorderSide(color: Colors.white.withOpacity(0.07)) : BorderSide.none,
          top: widget.expandVertically ? BorderSide.none : BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isActive
                          ? Color.lerp(const Color(0xFFBF5AF2), const Color(0xFF00E5FF), _pulse.value)!
                          : Colors.white.withOpacity(0.15),
                      boxShadow: widget.isActive ? [BoxShadow(color: const Color(0xFFBF5AF2).withOpacity(0.6), blurRadius: 8)] : [],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'COGNITIVE AGENT TRACE',
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF64D2FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                if (widget.isActive)
                  Text(
                    widget.statusText,
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 9,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(width: 6),
                Text(
                  '${widget.steps.length} steps',
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white.withOpacity(0.25),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),

          // ── Steps timeline ───────────────────────────────
          Expanded(
            child: widget.steps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.brain, color: Colors.white.withOpacity(0.1), size: 28),
                        const SizedBox(height: 8),
                        Text(
                          'No reasoning traces yet.\nIngest a log to start the agent.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.2), fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                    itemCount: widget.steps.length,
                    itemBuilder: (context, i) {
                      final step = widget.steps[i];
                      final c = _color(step.type);
                      final isLast = i == widget.steps.length - 1;

                      return TweenAnimationBuilder<double>(
                        key: ValueKey('step_${step.id}'),
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, child) {
                          final o = val.clamp(0.0, 1.0);
                          return Transform.translate(
                            offset: Offset(0, 16.0 * (1.0 - o)),
                            child: Opacity(
                              opacity: o,
                              child: child,
                            ),
                          );
                        },
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Rail
                              SizedBox(
                                width: 22,
                                child: Column(
                                  children: [
                                    Container(
                                      width: 22, height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: c.withOpacity(0.12),
                                        border: Border.all(color: c.withOpacity(0.5), width: 1),
                                      ),
                                      child: Icon(_icon(step.type), size: 11, color: c),
                                    ),
                                    if (!isLast)
                                      Expanded(child: Container(width: 1, color: Colors.white.withOpacity(0.06))),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Body
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Step ${step.id}  ',
                                            style: GoogleFonts.jetBrainsMono(color: Colors.white.withOpacity(0.25), fontSize: 8),
                                          ),
                                          Expanded(
                                            child: Text(
                                              step.title,
                                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            _timeLabel(step.time),
                                            style: GoogleFonts.jetBrainsMono(color: Colors.white.withOpacity(0.2), fontSize: 8),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        step.detail,
                                        style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.5), fontSize: 11, height: 1.4),
                                      ),
                                      if (step.cmd != null) ...[
                                        const SizedBox(height: 5),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.4),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                                          ),
                                          child: Text(
                                            step.cmd!,
                                            style: GoogleFonts.jetBrainsMono(color: const Color(0xFF64D2FF), fontSize: 9),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (widget.expandVertically) {
      return SizedBox.expand(child: shell);
    }
    return SizedBox(height: 270, child: shell);
  }
}
