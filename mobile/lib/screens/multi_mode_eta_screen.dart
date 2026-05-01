import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../providers/app_state.dart';
import '../widgets/glass_card.dart';
import '../theme/colors.dart';

class MultiModeEtaScreen extends StatefulWidget {
  const MultiModeEtaScreen({super.key});

  @override
  State<MultiModeEtaScreen> createState() => _MultiModeEtaScreenState();
}

class _MultiModeEtaScreenState extends State<MultiModeEtaScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _etaData;
  String? _errorMessage;

  // Default demo coordinates (e.g. Koramangala to Indiranagar, Bangalore)
  final double _defaultFromLat = 12.9345;
  final double _defaultFromLon = 77.6101;
  final double _defaultToLat = 12.9719;
  final double _defaultToLon = 77.6412;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMultiModeETAs();
    });
  }

  Future<void> _fetchMultiModeETAs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final state = Provider.of<AppState>(context, listen: false);
      
      // Use current device location if available, otherwise use defaults
      double fromLat = _defaultFromLat;
      double fromLon = _defaultFromLon;
      
      if (state.deviceContext.location.latitude != 0.0) {
        fromLat = state.deviceContext.location.latitude;
        fromLon = state.deviceContext.location.longitude;
      }

      // Hardcoded destination for demonstration/playground
      double toLat = _defaultToLat;
      double toLon = _defaultToLon;

      // Extract dynamic backend configuration from AppState
      // Wait, let's create a dynamic helper to resolve backend host
      final host = _getBackendHost(state);
      final url = Uri.parse('http://$host:8080/api/routing/multi-mode-eta?fromLat=$fromLat&fromLon=$fromLon&toLat=$toLat&toLon=$toLon');

      debugPrint('[MultiMode ETA] Fetching routes from: $url');
      final response = await http.get(url).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['ok'] == true) {
          setState(() {
            _etaData = jsonResponse['data'];
            _isLoading = false;
          });
          return;
        }
      }
      
      setState(() {
        _errorMessage = "Failed to fetch routing analytics from Ola Maps (Status ${response.statusCode}).";
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[MultiMode ETA] Network error: $e');
      
      setState(() {
        _errorMessage = "Connection error: ${e.toString()}\n\nNote: The Ola Maps API is heavily throttling parallel requests, which may take up to 50 seconds to resolve."; 
        _isLoading = false;
      });
    }
  }

  String _getBackendHost(AppState state) {
    // ADB Reverse Tunnel active - always route through USB loopback
    return 'localhost';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return "N/A";
    final minutes = (seconds / 60).round();
    if (minutes < 60) return "$minutes mins";
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    return remainingMins > 0 ? "${hours}h ${remainingMins}m" : "${hours}h";
  }

  String _formatDistance(int meters) {
    if (meters <= 0) return "N/A";
    if (meters < 1000) return "${meters}m";
    final km = meters / 1000.0;
    return "${km.toStringAsFixed(1)} km";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Multi-Mode Transit ETAs",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _isLoading ? null : _fetchMultiModeETAs,
          )
        ],
      ),
      body: SafeArea(
        child: _isLoading 
          ? _buildLoader()
          : _errorMessage != null
            ? _buildErrorView()
            : _buildContentGrid(),
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            "Querying Ola Maps for optimal paths...",
            style: GoogleFonts.outfit(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.alertTriangle, color: AppColors.danger, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? "An unexpected error occurred.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchMultiModeETAs,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text("Try Again"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildContentGrid() {
    if (_etaData == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Live Commute Options",
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            "Consolidated real-time transit telemetry",
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          _buildModeCard(
            title: "Car / Taxi",
            icon: LucideIcons.car,
            color: AppColors.primary,
            data: _etaData!['car'],
            trafficLabel: "Live Traffic Active",
          ),
          const SizedBox(height: 16),

          _buildModeCard(
            title: "Auto Rickshaw",
            icon: LucideIcons.armchair, // Substitute for auto
            color: AppColors.electricBlue,
            data: _etaData!['auto'],
            trafficLabel: "Moderate traffic scaling",
          ),
          const SizedBox(height: 16),

          _buildModeCard(
            title: "Two-Wheeler",
            icon: LucideIcons.bike,
            color: AppColors.warning,
            data: _etaData!['twoWheeler'],
            trafficLabel: "Filtered lane estimations",
          ),
          const SizedBox(height: 16),

          _buildModeCard(
            title: "Walking",
            icon: LucideIcons.footprints,
            color: Colors.greenAccent,
            data: _etaData!['walk'],
            trafficLabel: "Unconstrained by traffic",
          ),
          const SizedBox(height: 16),

          _buildModeCard(
            title: "Public Transit (Bus/Metro)",
            icon: LucideIcons.bus,
            color: AppColors.danger,
            data: _etaData!['transit'],
            trafficLabel: "Wait/Transfer algorithms",
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required IconData icon,
    required Color color,
    required Map<String, dynamic>? data,
    required String trafficLabel,
  }) {
    if (data == null) return const SizedBox();

    final int seconds = data['durationSeconds'] ?? 0;
    final int meters = data['distanceMeters'] ?? 0;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.2),
            radius: 24,
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(LucideIcons.shieldCheck, color: color.withValues(alpha: 0.7), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      trafficLabel,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDuration(seconds),
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                _formatDistance(meters),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
