import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import '../screens/digest_screen.dart';

/// Persistent floating notification bar — always pinned at the bottom of the
/// screen via [Positioned] inside a [Stack]. Never scrolls away.
///
/// State machine rendering:
///   NOMINAL        → green pill, subtle
///   RISK_FORMING   → amber glow
///   ACTION_NEEDED  → blue glow + CTA
///   CRITICAL       → red glow + pulsing opacity + CTA
class PersistentPulseBar extends StatefulWidget {
  const PersistentPulseBar({super.key});

  @override
  State<PersistentPulseBar> createState() => _PersistentPulseBarState();
}

class _PersistentPulseBarState extends State<PersistentPulseBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.75,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final snap = state.pulseSnapshot;
        final pulseState = snap['state'] as String? ?? 'NOMINAL';
        final content = snap['notificationContent'] as Map<String, dynamic>?;
        final digest = snap['notificationDigest'] as Map<String, dynamic>?;
        final nextAction = snap['nextAction'] as Map<String, dynamic>?;

        final title = content?['title'] as String? ?? 'Pulse active';
        final subtitle = content?['subtitle'] as String? ?? 'Monitoring…';
        final highlight = (content?['highlight'] as String?)?.isNotEmpty == true
            ? content!['highlight'] as String
            : digest?['highlight'] as String?;

        final isCritical = pulseState == 'CRITICAL';
        final isAction = pulseState == 'ACTION_NEEDED';

        final glowColor = _stateColor(pulseState);

        Widget bar = Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          decoration: BoxDecoration(
            // Slightly lighter than pure black so it's always distinguishable
            color: const Color(0xFF14141E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: glowColor.withValues(
                alpha: isCritical
                    ? 0.70
                    : isAction
                    ? 0.50
                    : 0.35,
              ),
              width: isCritical ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(
                  alpha: isCritical
                      ? 0.40
                      : isAction
                      ? 0.25
                      : 0.12,
                ),
                blurRadius: isCritical
                    ? 28
                    : isAction
                    ? 18
                    : 10,
                spreadRadius: isCritical ? 2 : 0,
                offset: const Offset(0, 2),
              ),
              // Subtle upward shadow for depth
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                // Animated state dot
                _StateDot(color: glowColor, animate: isCritical || isAction),
                const SizedBox(width: 11),

                // Title + subtitle + highlight
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.white60,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (highlight != null && highlight.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          highlight,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: glowColor,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // CTA for actionable states
                if ((isAction || isCritical) && nextAction != null)
                  _CtaButton(
                    label: nextAction['label'] as String? ?? 'Act',
                    color: glowColor,
                    onTap: () => state.dispatchPulseAction(nextAction),
                  )
                else
                  // State label badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: glowColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _stateLabel(pulseState),
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: glowColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        // Wrap CRITICAL in pulsing opacity
        if (isCritical) {
          bar = AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) =>
                Opacity(opacity: _pulseAnim.value, child: child),
            child: bar,
          );
        }

        // Tapping the bar (anywhere except the CTA) opens the Digest screen
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DigestScreen()),
          ),
          behavior: HitTestBehavior.opaque,
          child: bar,
        );
      },
    );
  }

  Color _stateColor(String state) {
    switch (state) {
      case 'CRITICAL':
        return const Color(0xFFFF4444);
      case 'ACTION_NEEDED':
        return const Color(0xFF4A9EFF);
      case 'RISK_FORMING':
        return const Color(0xFFFFB830);
      default:
        return const Color(0xFF44FF88);
    }
  }

  String _stateLabel(String state) {
    switch (state) {
      case 'CRITICAL':
        return 'CRITICAL';
      case 'ACTION_NEEDED':
        return 'ACT NOW';
      case 'RISK_FORMING':
        return 'WATCH';
      default:
        return 'NOMINAL';
    }
  }
}

// ─── Animated state dot ───────────────────────────────────────────────────────

class _StateDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _StateDot({required this.color, required this.animate});

  @override
  State<_StateDot> createState() => _StateDotState();
}

class _StateDotState extends State<_StateDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.animate) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StateDot old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.animate) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.75),
              blurRadius: 7,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CTA button ───────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CtaButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
