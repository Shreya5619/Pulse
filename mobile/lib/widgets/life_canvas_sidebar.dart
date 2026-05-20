import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/lifecanvas_graph.dart';

class LifeCanvasSidebar extends StatelessWidget {
  final LifeCanvasGraph graph;
  final bool isGalaxyView;
  final ValueChanged<bool> onViewToggle;
  final VoidCallback onRefresh;

  const LifeCanvasSidebar({
    super.key,
    required this.graph,
    required this.isGalaxyView,
    required this.onViewToggle,
    required this.onRefresh,
  });

  Color _themeColor(int index) {
    const colors = [
      Color(0xFF00E5FF), Color(0xFFBF5AF2), Color(0xFFFFB300),
      Color(0xFF4EE2C9), Color(0xFF0A84FF), Color(0xFFFF5252),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final themes = graph.nodes.where((n) => n.type == 'THEME').toList();
    final events = graph.nodes.where((n) => n.type == 'LIFE_EVENT').toList();

    return Drawer(
      backgroundColor: const Color(0xFF070912),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Brand ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      colors: [Color(0xFFBF5AF2), Color(0xFF00E5FF)],
                    ).createShader(r),
                    child: Text(
                      'LIFECANVAS',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  Text(
                    'COGNITIVE ENGINE',
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 9,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _divider(),

            // ── View Toggle ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('VISUALIZATION'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _viewChip('Galaxy', LucideIcons.globe, isGalaxyView, () => onViewToggle(true)),
                      const SizedBox(width: 8),
                      _viewChip('River', LucideIcons.gitCommit, !isGalaxyView, () => onViewToggle(false)),
                    ],
                  ),
                ],
              ),
            ),

            _divider(),

            // ── Stats ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('GRAPH STATS'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statBox('${graph.nodes.length}', 'NODES', const Color(0xFF00E5FF)),
                      const SizedBox(width: 10),
                      _statBox('${graph.edges.length}', 'EDGES', const Color(0xFFBF5AF2)),
                      const SizedBox(width: 10),
                      _statBox('${events.length}', 'EVENTS', const Color(0xFFFFB300)),
                    ],
                  ),
                ],
              ),
            ),

            _divider(),

            // ── Themes ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _label('ACTIVE THEMES'),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: themes.isEmpty
                  ? Center(
                      child: Text(
                        'No themes yet.\nIngest a log to seed themes.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.2), fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: themes.length,
                      itemBuilder: (context, i) {
                        final t = themes[i];
                        final c = _themeColor(i);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: c),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  t.label,
                                  style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Text(
                                '${(t.importance * 100).toInt()}%',
                                style: GoogleFonts.jetBrainsMono(color: c.withOpacity(0.7), fontSize: 10),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            _divider(),

            // ── Refresh ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: onRefresh,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.refreshCcw, color: const Color(0xFF00E5FF), size: 15),
                      const SizedBox(width: 8),
                      Text(
                        'REFRESH GRAPH',
                        style: GoogleFonts.outfit(color: const Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(height: 1, color: Colors.white.withOpacity(0.06));

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.jetBrainsMono(color: Colors.white.withOpacity(0.3), fontSize: 9, letterSpacing: 1.5),
      );

  Widget _viewChip(String label, IconData icon, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF00E5FF).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? const Color(0xFF00E5FF).withOpacity(0.4) : Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: active ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.4)),
              const SizedBox(width: 5),
              Text(label, style: GoogleFonts.outfit(color: active ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.outfit(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: GoogleFonts.jetBrainsMono(color: Colors.white.withOpacity(0.3), fontSize: 8, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
