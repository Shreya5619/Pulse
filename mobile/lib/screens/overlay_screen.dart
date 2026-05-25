import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:convert';

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  String highlight = "Pulse Active";
  List<String> actionItems = [];
  String digest = "Monitoring your notifications...";
  bool isSurge = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    debugPrint("------------------------------------------");
    debugPrint("[OverlayScreen] INIT STATE CALLED");
    debugPrint("------------------------------------------");
    
    FlutterOverlayWindow.overlayListener.listen((event) {
      try {
        final data = jsonDecode(event.toString());
        final bool incomingSurge = data['isSurge'] ?? false;
        
        setState(() {
          highlight = data['highlight'] ?? highlight;
          actionItems = List<String>.from(data['actionItems'] ?? actionItems);
          digest = data['digest'] ?? digest;
          isSurge = incomingSurge;
        });

        // Auto-expand on Surge if not already expanded
        if (incomingSurge && !_isExpanded) {
          _toggleExpand();
        }
      } catch (e) {
        debugPrint("[Overlay] Error parsing data: $e");
      }
    });
  }

  void _toggleExpand() async {
    debugPrint("[OverlayScreen] Toggling expansion. Current state: $_isExpanded");
    if (_isExpanded) {
      await FlutterOverlayWindow.resizeOverlay(140, 140, true);
    } else {
      await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, 600, true);
    }
    setState(() {
      _isExpanded = !_isExpanded;
    });
    debugPrint("[OverlayScreen] Expansion toggled to: $_isExpanded");
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Material(
          color: Colors.transparent,
          child: _isExpanded ? _buildCard() : _buildBubble(),
        );
      },
    );
  }

  Widget _buildBubble() {
    return GestureDetector(
      onTap: _toggleExpand,
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isSurge ? Colors.red : Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Icon(
            Icons.notifications_active,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF13161A),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: (isSurge ? Colors.redAccent : Colors.blueAccent).withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isSurge ? Colors.redAccent : Colors.blueAccent).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSurge ? Icons.bolt : Icons.auto_awesome,
                        size: 14,
                        color: isSurge ? Colors.redAccent : Colors.blueAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSurge ? 'SURGE DETECTED' : 'PULSE AI',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.blueAccent,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _toggleExpand,
                  icon: const Icon(Icons.close, size: 22, color: Colors.white30),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              highlight,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            if (actionItems.isNotEmpty)
              ...actionItems.take(3).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: isSurge ? Colors.redAccent : Colors.blueAccent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                digest,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _toggleExpand,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSurge ? Colors.redAccent : Colors.blueAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
