import 'package:flutter/material.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

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
};

List<ScreenSession> generateRawSessions() {
  return [
    ScreenSession(8.0, 9.5, [
      AppActivity('Messages', 8.0, 8.4, appColorMap['Messages']!),
      AppActivity('Chrome', 8.4, 9.5, appColorMap['Chrome']!),
    ]),
    ScreenSession(9.7, 11.0, [
      AppActivity('WhatsApp', 9.7, 10.2, appColorMap['WhatsApp']!),
      AppActivity('Instagram', 10.2, 11.0, appColorMap['Instagram']!),
    ]),
    ScreenSession(11.3, 13.0, [
      AppActivity('Chrome', 11.3, 12.3, appColorMap['Chrome']!),
      AppActivity('YouTube', 12.3, 13.0, appColorMap['YouTube']!),
    ]),
    ScreenSession(13.3, 15.0, [
      AppActivity('Spotify', 13.3, 14.0, appColorMap['Spotify']!),
      AppActivity('Twitter', 14.0, 15.0, appColorMap['Twitter']!),
    ]),
    ScreenSession(15.3, 17.0, [
      AppActivity('Maps', 15.3, 16.0, appColorMap['Maps']!),
      AppActivity('Messages', 16.0, 17.0, appColorMap['Messages']!),
    ]),
    ScreenSession(17.3, 19.0, [
      AppActivity('Instagram', 17.3, 18.2, appColorMap['Instagram']!),
      AppActivity('YouTube', 18.2, 19.0, appColorMap['YouTube']!),
    ]),
    ScreenSession(19.3, 22.0, [
      AppActivity('WhatsApp', 19.3, 20.0, appColorMap['WhatsApp']!),
      AppActivity('Chrome', 20.0, 21.0, appColorMap['Chrome']!),
      AppActivity('Spotify', 21.0, 22.0, appColorMap['Spotify']!),
    ]),
  ];
}

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

  late List<String> appOrder;
  late Map<String, List<AppActivity>> appActivities;

  @override
  void initState() {
    super.initState();
    rawSessions = generateRawSessions();

    // Collect unique app names
    final Set<String> apps = {};
    for (final session in rawSessions) {
      for (final activity in session.activities) {
        apps.add(activity.appName);
      }
    }
    appOrder = ['Screen', ...apps.toList()..sort()];

    // Build per‑app activity lists
    appActivities = {};
    for (final app in appOrder) {
      if (app == 'Screen') {
        final List<AppActivity> screenActs = [];
        for (final session in rawSessions) {
          screenActs.add(
            AppActivity(
              'Screen',
              session.startHours,
              session.endHours,
              Colors.cyanAccent,
            ),
          );
        }
        appActivities[app] = screenActs;
      } else {
        appActivities[app] = _activitiesForApp(app, rawSessions);
      }
    }
  }

  List<AppActivity> _activitiesForApp(
    String appName,
    List<ScreenSession> sessions,
  ) {
    final result = <AppActivity>[];
    for (final session in sessions) {
      for (final activity in session.activities) {
        if (activity.appName == appName) {
          result.add(
            AppActivity(
              appName,
              activity.startHours,
              activity.endHours,
              activity.color,
            ),
          );
        }
      }
    }
    return result;
  }

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
          const Text(
            'PULSE • Timeline',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          // Colour legend (tiny, scrollable)
          Container(
            constraints: const BoxConstraints(maxHeight: 50, maxWidth: 200),
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
