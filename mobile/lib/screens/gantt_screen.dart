import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class GanttScreen extends StatelessWidget {
  const GanttScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B0B0D),
      body: SafeArea(child: PremiumTimeline()),
    );
  }
}

// ------------------------- DATA MODELS -------------------------

class AppActivity {
  final String appName;
  final double startHours;
  final double endHours;
  final Color color;

  AppActivity(this.appName, this.startHours, this.endHours, this.color);
}

class ScreenSession {
  final double startHours;
  final double endHours;
  final List<AppActivity> activities;

  ScreenSession(this.startHours, this.endHours, this.activities);
}

const Map<String, Color> appColorMap = {
  'Messages': Color(0xFF4ADE80),
  'Chrome': Color(0xFF60A5FA),
  'Maps': Color(0xFFFBBF24),
  'Instagram': Color(0xFFA78BFA),
  'YouTube': Color(0xFFE57373),
  'Spotify': Color(0xFF81C784),
  'WhatsApp': Color(0xFF64B5F6),
  'Twitter': Color(0xFF90CAF9),
  'Notes': Color(0xFFFFD54F),
  'Camera': Color(0xFFFF8A65),
  'Other': Color(0xFF94A3B8),
};

const Map<String, String> packageToName = {
  'com.whatsapp': 'WhatsApp',
  'com.instagram.android': 'Instagram',
  'com.android.chrome': 'Chrome',
  'com.google.android.apps.maps': 'Maps',
  'com.google.android.youtube': 'YouTube',
  'com.spotify.music': 'Spotify',
  'com.twitter.android': 'Twitter',
  'com.google.android.apps.messaging': 'Messages',
  'com.google.android.keep': 'Notes',
  'com.android.camera': 'Camera',
  'com.google.android.calendar': 'Calendar',
  'com.android.settings': 'Settings',
  'com.google.android.gm': 'Gmail',
  'com.slack': 'Slack',
  'com.microsoft.teams': 'Teams',
};

// List<ScreenSession> generateRawSessions() { ... } // Removed as we use real data

// ------------------------- MAIN WIDGET -------------------------

class PremiumTimeline extends StatefulWidget {
  const PremiumTimeline({super.key});

  @override
  State<PremiumTimeline> createState() => _PremiumTimelineState();
}

class _PremiumTimelineState extends State<PremiumTimeline> {
  bool expanded = false;
  late List<ScreenSession> rawSessions;
  double _currentScale = 1.0; // track zoom scale for adaptive labels

  static const double startHour = 0.0; // start at midnight for long-term data
  static const double endHour = 24.0; // 24h format
  double get totalHours => endHour - startHour;
  static const double baseHoursPerScreen = 6.0; // at scale=1, visible range ~6h
  double _baseWidth = 1200.0; // base width at scale=1

  late List<String> appOrder = [];
  late Map<String, List<AppActivity>> appActivities = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRealData();
  }

  Future<void> _loadRealData() async {
    setState(() => isLoading = true);

    final appState = Provider.of<AppState>(context, listen: false);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final usageData = await appState.getAppUsage(startOfDay, now);

    final List<ScreenSession> sessions = [];
    final Map<String, List<AppActivity>> activitiesByApp = {};
    final Set<String> activeApps = {};

    for (var data in usageData) {
      final String pkg = data['packageName'];
      final String name = packageToName[pkg] ?? pkg.split('.').last;
      final int startMs = data['startTime'];
      final int endMs = data['endTime'];

      final double startHour = _msToHour(startMs);
      final double endHour = _msToHour(endMs);

      final Color color = appColorMap[name] ?? appColorMap['Other']!;

      final activity = AppActivity(name, startHour, endHour, color);

      if (!activitiesByApp.containsKey(name)) {
        activitiesByApp[name] = [];
      }
      activitiesByApp[name]!.add(activity);
      activeApps.add(name);

      // Also build sessions for the 'Screen' track
      // (Simplification: treat each app foreground period as a screen session)
      sessions.add(ScreenSession(startHour, endHour, [activity]));
    }

    setState(() {
      rawSessions = sessions;
      appActivities = activitiesByApp;

      // Add 'Screen' track
      final List<AppActivity> screenActs = [];
      for (final session in sessions) {
        screenActs.add(
          AppActivity(
            'Screen',
            session.startHours,
            session.endHours,
            Colors.cyanAccent,
          ),
        );
      }
      appActivities['Screen'] = screenActs;

      appOrder = ['Screen', ...activeApps.toList()..sort()];
      isLoading = false;
    });
  }

  double _msToHour(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return dt.hour + (dt.minute / 60.0) + (dt.second / 3600.0);
  }

  // List<AppActivity> _activitiesForApp(...) { ... } // Removed

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenWidth = MediaQuery.of(context).size.width;
    // base width: at scale=1, visible width = screen width, content width = screenWidth * (totalHours / baseHoursPerScreen)
    _baseWidth = screenWidth * (totalHours / baseHoursPerScreen);
  }

  double hourToX(double hour) => (hour - startHour) / totalHours * _baseWidth;

  // Determine hour label step based on current scale (pixels per hour)
  int _getHourStep() {
    final pixelsPerHour = _baseWidth / totalHours;
    final visiblePixelsPerHour = pixelsPerHour * _currentScale;
    if (visiblePixelsPerHour > 50) return 1; // every hour
    if (visiblePixelsPerHour > 20) return 3; // every 3 hours
    if (visiblePixelsPerHour > 10) return 6; // every 6 hours
    return 12; // every 12 hours
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final int rowCount = expanded ? appOrder.length : 1;
          const double rowHeight = 32.0;
          final double totalHeight = 60.0 + (rowCount * rowHeight);
          final containerHeight = totalHeight.clamp(120.0, 600.0);

          return Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1E2E).withValues(alpha: 0.7),
                  const Color(0xFF0B0F1A).withValues(alpha: 0.9),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 30,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  if (isLoading)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.cyanAccent),
                      ),
                    )
                  else
                    SizedBox(
                      height: containerHeight - 60,
                    child: InteractiveViewer(
                      minScale: 0.1, // zoom out very far
                      maxScale: double.infinity, // no upper limit
                      constrained: false,
                      scaleEnabled: true,
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(20),
                      onInteractionUpdate: (details) {
                        setState(() {
                          _currentScale = details.scale;
                        });
                      },
                      child: SizedBox(
                        width: _baseWidth,
                        height: rowCount * rowHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Time ruler lines (vertical)
                            ..._buildRulerLines(rowCount, rowHeight),
                            // Adaptive hour numbers
                            ..._buildAdaptiveHourNumbers(rowHeight),
                            // Tracks
                            for (int i = 0; i < rowCount; i++)
                              _buildTrackRow(
                                i,
                                rowHeight,
                                expanded ? appOrder[i] : 'Screen',
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
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Flexible(
            child: Text(
              'PULSE • Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Colour legend (tiny, scrollable)
          Flexible(
            flex: 2,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 50, maxWidth: 220),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: appOrder.where((app) => app != 'Screen').map((app) {
                    final color =
                        appActivities[app]?.firstOrNull?.color ?? Colors.grey;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            app,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Expand/collapse icon
          GestureDetector(
            onTap: () => setState(() => expanded = !expanded),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                expanded ? Icons.compress : Icons.expand,
                size: 20,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRulerLines(int rowCount, double rowHeight) {
    final step = _getHourStep();
    final widgets = <Widget>[];
    for (int hour = startHour.floor(); hour <= endHour.floor(); hour += step) {
      final x = hourToX(hour.toDouble());
      widgets.add(
        Positioned(
          left: x,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildAdaptiveHourNumbers(double rowHeight) {
    final step = _getHourStep();
    final widgets = <Widget>[];
    for (int hour = startHour.floor(); hour <= endHour.floor(); hour += step) {
      final x = hourToX(hour.toDouble());
      String label = hour.toString();
      // For 12‑hour step, also show AM/PM? Keep simple: 0,12,24
      widgets.add(
        Positioned(
          left: x - 12,
          top: -24,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white38,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildTrackRow(int rowIndex, double rowHeight, String appName) {
    final activities = appActivities[appName] ?? [];
    final yOffset = rowIndex * rowHeight;

    return Positioned(
      top: yOffset,
      left: 0,
      right: 0,
      height: rowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Subtle alternating row background
          Container(
            height: rowHeight,
            color: rowIndex % 2 == 0
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.transparent,
          ),
          // Activity bars (thin, no text)
          for (final act in activities)
            Positioned(
              left: hourToX(act.startHours),
              width: (hourToX(act.endHours) - hourToX(act.startHours)).clamp(
                2.0,
                double.infinity,
              ),
              top: (rowHeight - 12) / 2,
              height: 12,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: act.color.withValues(
                    alpha: appName == 'Screen' ? 0.7 : 0.85,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: appName == 'Screen'
                      ? [
                          BoxShadow(
                            color: act.color.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
