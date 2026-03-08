import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/src/services/audio_analysis_service_stub.dart'
  if (dart.library.io) 'package:usafe_front_end/src/services/audio_analysis_service.dart';

class SafetyMapScreen extends StatefulWidget {
  final Map<String, dynamic> factors;
  final double? latitude;
  final double? longitude;

  const SafetyMapScreen({
    super.key,
    this.factors = const {},
    this.latitude,
    this.longitude,
  });

  @override
  State<SafetyMapScreen> createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> {
  GoogleMapController? _mapController;
  String _darkMapStyle = '';

  final AudioAnalysisService _audioService = AudioAnalysisService();
  bool _isSafetyModeActive = false;
  bool _isDangerDialogOpen = false;

  Color _micStatusColor = Colors.grey;
  String _micStatusText = 'Mic Off';

  CameraPosition get _initialPosition {
    final lat = widget.latitude ?? 37.7749;
    final lng = widget.longitude ?? -122.4194;
    return CameraPosition(target: LatLng(lat, lng), zoom: 14.2);
  }

  Set<Marker> get _markers {
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat == null || lng == null) return {};
    return {
      Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(lat, lng),
        infoWindow: const InfoWindow(title: 'You are here'),
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    _loadMapStyle();

    _audioService.initialize();
    _audioService.onDistressDetected = (event, confidence) {
      if (_isSafetyModeActive) {
        _showDangerDialog(event);
      }
    };
  }

  void _toggleSafetyMode() {
    setState(() {
      _isSafetyModeActive = !_isSafetyModeActive;
      if (_isSafetyModeActive) {
        _audioService.startListening();
        _micStatusColor = Colors.redAccent;
        _micStatusText = 'Listening...';
      } else {
        _audioService.stopListening();
        _micStatusColor = Colors.grey;
        _micStatusText = 'Mic Off';
      }
    });
  }

  void _showDangerDialog(String reason) {
    if (_isDangerDialogOpen) return;
    _isDangerDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Text(
          'DISTRESS DETECTED!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Detected signal: $reason\n\nTriggering Emergency Protocol...',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _isDangerDialogOpen = false;
              Navigator.pop(context);
            },
            child: const Text('CANCEL ALARM',
                style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () {
              _isDangerDialogOpen = false;
              Navigator.pop(context);
            },
            child: const Text('CALL SOS', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMapStyle() async {
    _darkMapStyle = '''
    [
      {"elementType":"geometry","stylers":[{"color":"#212121"}]},
      {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
      {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
      {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
      {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#181818"}]},
      {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]}
    ]
    ''';
  }

  @override
  void dispose() {
    if (_isSafetyModeActive) {
      _audioService.stopListening();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            tooltip: 'View API Values',
            onPressed: _showApiValuesSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_darkMapStyle.isNotEmpty) {
                _mapController!.setMapStyle(_darkMapStyle);
              }
            },
            markers: _markers,
            circles: const {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            top: 120,
            left: 20,
            child: _buildMicStatusPill(),
          ),
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'recenter',
                  backgroundColor: const Color(0xFF1E1E1E),
                  onPressed: () {
                    final lat = widget.latitude;
                    final lng = widget.longitude;
                    if (lat != null && lng != null && _mapController != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14.2),
                      );
                    }
                  },
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'safety_mode',
                  backgroundColor: _isSafetyModeActive
                      ? Colors.redAccent
                      : const Color(0xFF1E1E1E),
                  onPressed: _toggleSafetyMode,
                  child: Icon(_isSafetyModeActive ? Icons.mic : Icons.mic_none,
                      color: Colors.white),
                ),
              ],
            ),
          ),
          // Debug factors panel intentionally hidden from production UI.
        ],
      ),
    );
  }

  Widget _buildFactorsPanel() {
    final time =
        (widget.factors['time'] as Map?)?.cast<String, dynamic>() ?? {};
    final location =
        (widget.factors['location'] as Map?)?.cast<String, dynamic>() ?? {};
    final env =
        (widget.factors['environment'] as Map?)?.cast<String, dynamic>() ?? {};
    final trafficSource = (env['trafficSource'] ?? 'time-estimate').toString();
    final populationSource =
        (env['populationSource'] ?? 'places-density-estimate').toString();
    final trafficFallback = env['trafficFallback'] == true;
    final populationFallback = env['populationFallback'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                  child: _panelTile(
                      'Police', _distanceText(location['closestPoliceKm']))),
              Expanded(
                  child: _panelTile('Hospital',
                      _distanceText(location['closestHospitalKm']))),
              Expanded(
                  child: _panelTile(
                      'Traffic', '${env['trafficLevel'] ?? 'unknown'}')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _panelTile('Population',
                      '${env['populationDensity'] ?? 'unknown'}')),
              Expanded(child: _panelTile('Hour', '${time['hour24'] ?? '--'}')),
              Expanded(
                child: _panelTile(
                  'Graveyard',
                  (time['isGraveyardShift'] == true) ? 'Yes' : 'No',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _sourceChip('Traffic', trafficSource, trafficFallback),
                _sourceChip('Population', populationSource, populationFallback),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceChip(String label, String source, bool isFallback) {
    final color = isFallback ? Colors.orange : const Color(0xFF00E676);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$label: ${isFallback ? 'Fallback' : 'Live'}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _panelTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _distanceText(dynamic kmValue) {
    if (kmValue == null) return 'N/A';
    final asNum = (kmValue as num).toDouble();
    return '${asNum.toStringAsFixed(2)} km';
  }

  void _showApiValuesSheet() {
    final time =
        (widget.factors['time'] as Map?)?.cast<String, dynamic>() ?? {};
    final location =
        (widget.factors['location'] as Map?)?.cast<String, dynamic>() ?? {};
    final env =
        (widget.factors['environment'] as Map?)?.cast<String, dynamic>() ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live API Values',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _apiValueRow('Closest Police', _distanceText(location['closestPoliceKm'])),
                _apiValueRow('Closest Hospital', _distanceText(location['closestHospitalKm'])),
                _apiValueRow('Traffic Level', '${env['trafficLevel'] ?? 'unknown'}'),
                _apiValueRow('Population Density', '${env['populationDensity'] ?? 'unknown'}'),
                _apiValueRow('Hour (24h)', '${time['hour24'] ?? '--'}'),
                _apiValueRow('Graveyard Shift', (time['isGraveyardShift'] == true) ? 'Yes' : 'No'),
                _apiValueRow('Traffic Source', '${env['trafficSource'] ?? 'unknown'}'),
                _apiValueRow('Population Source', '${env['populationSource'] ?? 'unknown'}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _apiValueRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _micStatusColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(
            _isSafetyModeActive ? Icons.hearing : Icons.mic_off,
            size: 14,
            color: _micStatusColor,
          ),
          const SizedBox(width: 6),
          Text(
            _micStatusText,
            style: TextStyle(color: _micStatusColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
