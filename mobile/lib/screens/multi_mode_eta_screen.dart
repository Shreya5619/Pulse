import 'dart:convert';
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

  // Default demo coordinates
  final double _defaultToLat = 12.9719;
  final double _defaultToLon = 77.6412;

  final List<Map<String, dynamic>> _presets = [
    {"name": "Work (Indiranagar)", "lat": 12.9719, "lon": 77.6412},
    {"name": "College (RVCE)", "lat": 12.9226, "lon": 77.5174},
    {"name": "Gym (HSR Layout)", "lat": 12.9100, "lon": 77.6300},
    {"name": "City Center (MG Road)", "lat": 12.9716, "lon": 77.5946},
  ];

  late TextEditingController _destLatController;
  late TextEditingController _destLonController;
  late TextEditingController _fromLatController;
  late TextEditingController _fromLonController;

  String _toLocationName = "Work (Indiranagar)";
  final String _fromLocationName = "Current Location";
  String? _selectedPreset;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _toFocus = FocusNode();
  final FocusNode _fromFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AppState>(context, listen: false);
    _destLatController = TextEditingController(text: _defaultToLat.toString());
    _destLonController = TextEditingController(text: _defaultToLon.toString());
    _fromLatController = TextEditingController(
      text: state.deviceContext.location.latitude.toString(),
    );
    _fromLonController = TextEditingController(
      text: state.deviceContext.location.longitude.toString(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMultiModeETAs();
    });
  }

  @override
  void dispose() {
    _destLatController.dispose();
    _destLonController.dispose();
    _fromLatController.dispose();
    _fromLonController.dispose();
    _scrollController.dispose();
    _toFocus.dispose();
    _fromFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchMultiModeETAs({bool force = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final state = Provider.of<AppState>(context, listen: false);

      // Use current device location if available, otherwise use defaults
      double fromLat =
          double.tryParse(_fromLatController.text) ??
          state.deviceContext.location.latitude;
      double fromLon =
          double.tryParse(_fromLonController.text) ??
          state.deviceContext.location.longitude;

      // Hardcoded destination or manual input
      double toLat = double.tryParse(_destLatController.text) ?? _defaultToLat;
      double toLon = double.tryParse(_destLonController.text) ?? _defaultToLon;

      // Extract dynamic backend configuration from AppState
      final host = _getBackendHost(state);
      final userId = state.userId;
      final url = Uri.parse(
        'http://$host:8080/api/routing/multi-mode-eta?userId=$userId&deviceId=$userId&fromLat=$fromLat&fromLon=$fromLon&toLat=$toLat&toLon=$toLon${force ? "&force=true" : ""}',
      );

      debugPrint('[MultiMode ETA] Fetching routes from: $url');
      final response = await http
          .get(url, headers: {'X-Device-Id': userId, 'X-User-Id': userId})
          .timeout(const Duration(seconds: 60));

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
        _errorMessage =
            "Failed to fetch routing analytics from Ola Maps (Status ${response.statusCode}).";
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[MultiMode ETA] Network error: $e');

      setState(() {
        _errorMessage =
            "Connection error: ${e.toString()}\n\nNote: The Ola Maps API is heavily throttling parallel requests, which may take up to 50 seconds to resolve.";
        _isLoading = false;
      });
    }
  }

  String _getBackendHost(AppState state) {
    return '172.20.10.5';
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

  void _updateActiveDestination() {
    final state = Provider.of<AppState>(context, listen: false);
    double toLat = double.tryParse(_destLatController.text) ?? _defaultToLat;
    double toLon = double.tryParse(_destLonController.text) ?? _defaultToLon;
    double fromLat =
        double.tryParse(_fromLatController.text) ??
        state.deviceContext.location.latitude;
    double fromLon =
        double.tryParse(_fromLonController.text) ??
        state.deviceContext.location.longitude;

    setState(() {
      if (_selectedPreset == null) _toLocationName = "Custom Destination";
    });

    state.setSimulatedLocation(fromLat, fromLon, "Simulated Start");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Simulation parameters synced to backend"),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    _fetchMultiModeETAs(force: true);
  }

  void _useCurrentLocation() {
    // In a real scenario we'd use Geolocator. But for now, we'll try to get
    // the 'Live' location if available, or just a default.
    // Note: AppState handles the actual live GPS updates in the background.
    final state = Provider.of<AppState>(context, listen: false);
    _fromLatController.text = state.deviceContext.location.latitude.toString();
    _fromLonController.text = state.deviceContext.location.longitude.toString();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Reset to Live coordinates")));
  }

  void _showEditPresetDialog({Map<String, dynamic>? preset}) {
    final nameController = TextEditingController(text: preset?['name'] ?? "");
    final latController = TextEditingController(
      text: preset?['lat']?.toString() ?? "",
    );
    final lonController = TextEditingController(
      text: preset?['lon']?.toString() ?? "",
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F1426),
        title: Text(
          preset == null ? "Add Preset" : "Edit Preset",
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCoordInput("Name", nameController),
            const SizedBox(height: 12),
            _buildCoordInput("Lat", latController),
            const SizedBox(height: 12),
            _buildCoordInput("Lon", lonController),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  if (preset != null) {
                    preset['name'] = nameController.text;
                    preset['lat'] = double.parse(latController.text);
                    preset['lon'] = double.parse(lonController.text);
                  } else {
                    _presets.add({
                      "name": nameController.text,
                      "lat": double.parse(latController.text),
                      "lon": double.parse(lonController.text),
                    });
                  }
                });
                Navigator.pop(context);
              }
            },
            child: const Text(
              "Save",
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
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
          ),
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
            const Icon(
              LucideIcons.alertTriangle,
              color: AppColors.danger,
              size: 48,
            ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentGrid() {
    if (_etaData == null) return const SizedBox();

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Live Commute Options",
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildLocationSummary(),
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
          const SizedBox(height: 32),
          _buildDestinationConfig(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLocationSummary() {
    final state = Provider.of<AppState>(context);
    double fromLat =
        double.tryParse(_fromLatController.text) ??
        state.deviceContext.location.latitude;
    double fromLon =
        double.tryParse(_fromLonController.text) ??
        state.deviceContext.location.longitude;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
              );
              _fromFocus.requestFocus();
            },
            child: _locationRow(
              LucideIcons.mapPin,
              "FROM",
              state.deviceContext.location.status.isEmpty
                  ? _fromLocationName
                  : state.deviceContext.location.status,
              "(${fromLat.toStringAsFixed(4)}, ${fromLon.toStringAsFixed(4)})",
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(color: Colors.white10),
          ),
          InkWell(
            onTap: () {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
              );
              _toFocus.requestFocus();
            },
            child: _locationRow(
              LucideIcons.navigation,
              "TO",
              _toLocationName,
              "(${_destLatController.text}, ${_destLonController.text})",
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationRow(IconData icon, String label, String name, String coords) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 10,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                name,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Text(
          coords,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildDestinationConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "DESTINATION PRESETS",
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white30,
                letterSpacing: 1.2,
              ),
            ),
            IconButton(
              icon: const Icon(
                LucideIcons.plusCircle,
                size: 16,
                color: Colors.white30,
              ),
              onPressed: () => _showEditPresetDialog(),
              tooltip: "Add New Preset",
            ),
          ],
        ),
        _buildPresetDropdown(),
        const SizedBox(height: 24),
        Text(
          "MANUAL START (FROM)",
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white30,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCoordInput(
                "Lat",
                _fromLatController,
                focusNode: _fromFocus,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildCoordInput("Lon", _fromLonController)),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: _useCurrentLocation,
              icon: const Icon(LucideIcons.mapPin, size: 18),
              style: IconButton.styleFrom(backgroundColor: Colors.white10),
              tooltip: "Use Current Location",
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "MANUAL TARGET (TO)",
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white30,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCoordInput(
                "Lat",
                _destLatController,
                focusNode: _toFocus,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildCoordInput("Lon", _destLonController)),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _updateActiveDestination,
            icon: const Icon(LucideIcons.zap),
            label: const Text("SYNC & CALCULATE ETAs"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetDropdown() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPreset,
                hint: const Text(
                  "Select a preset destination",
                  style: TextStyle(color: Colors.white30, fontSize: 14),
                ),
                dropdownColor: const Color(0xFF0F1426),
                isExpanded: true,
                icon: const Icon(
                  LucideIcons.chevronDown,
                  color: Colors.white30,
                ),
                items: _presets.map((p) {
                  return DropdownMenuItem<String>(
                    value: p['name'],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          p['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.trash2,
                            size: 14,
                            color: Colors.redAccent,
                          ),
                          onPressed: () {
                            setState(() {
                              _presets.remove(p);
                              if (_selectedPreset == p['name']) {
                                _selectedPreset = null;
                              }
                            });
                            // Close the dropdown menu to reflect changes
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  final preset = _presets.firstWhere((p) => p['name'] == val);
                  setState(() {
                    _selectedPreset = val;
                    _destLatController.text = preset['lat'].toString();
                    _destLonController.text = preset['lon'].toString();
                    _toLocationName = val!;
                  });
                },
              ),
            ),
          ),
        ),
        if (_selectedPreset != null) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              LucideIcons.edit3,
              color: Colors.white30,
              size: 20,
            ),
            onPressed: () {
              final preset = _presets.firstWhere(
                (p) => p['name'] == _selectedPreset,
              );
              _showEditPresetDialog(preset: preset);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCoordInput(
    String label,
    TextEditingController controller, {
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      keyboardType: TextInputType.text,
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

    final int seconds = (data['durationSeconds'] as num?)?.toInt() ?? 0;
    final int meters = (data['distanceMeters'] as num?)?.toInt() ?? 0;

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
                    Icon(
                      LucideIcons.shieldCheck,
                      color: color.withValues(alpha: 0.7),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trafficLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
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
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
