import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:usafe_front_end/src/services/audio_analysis_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'communityReport_screen.dart';

class SafetyMapScreen extends StatefulWidget {
  const SafetyMapScreen({
    Key? key,
    this.selectLocationForReport = false,
  }) : super(key: key);

  final bool selectLocationForReport;

  @override
  _SafetyMapScreenState createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  String _mapStyle = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  
  final AudioAnalysisService _audioService = AudioAnalysisService();
  bool _isSafetyModeActive = false;
  
  Timer? _dangerTimer;
  bool _isDangerDialogOpen = false;
  StateSetter? _dangerDialogSetState;
  Marker? _selectedMarker;
  bool _isResolvingLocation = false;

  static const LatLng _fallbackPosition = LatLng(37.7749, -122.4194);
  LatLng? _currentLatLng;
  bool _mapReady = false;

  Color _micStatusColor = Colors.grey;
  String _micStatusText = "Mic Off";
  bool _didShowSelectionHint = false;
  bool _isSearchingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _initCurrentLocation();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 300, end: 500).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _audioService.initialize();
    _audioService.onDistressDetected = (event, confidence) {
      if (_isSafetyModeActive) {
        _showDangerDialog(event);
      }
    };

    if (widget.selectLocationForReport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didShowSelectionHint) return;
        _didShowSelectionHint = true;
        _showStatusSnack("Please select a location.");
      });
    }

    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _toggleSafetyMode() {
    setState(() {
      _isSafetyModeActive = !_isSafetyModeActive;
      if (_isSafetyModeActive) {
        _audioService.startListening();
        _micStatusColor = Colors.redAccent;
        _micStatusText = "Listening...";
      } else {
        _audioService.stopListening();
        _micStatusColor = Colors.grey;
        _micStatusText = "Mic Off";
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
        title: const Text('DISTRESS DETECTED!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          )
        ],
      ),
    );
  }

  void _closeDangerDialog() {
    if (!_isDangerDialogOpen || !mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _isDangerDialogOpen = false;
    _dangerDialogSetState = null;
  }

  void _showStatusSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _useCurrentLocationForReport() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          _showStatusSnack("Location permission denied.");
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showStatusSnack("Location permission permanently denied.");
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      _currentLatLng = latLng;
      _selectedMarker = Marker(
        markerId: const MarkerId("selected_location"),
        position: latLng,
      );
      if (mounted) {
        setState(() {});
      }
      await _goToReportWithLocation(
        latLng,
        source: "Current location",
      );
    } catch (_) {
      _showStatusSnack("Unable to get current location.");
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final query = value.trim();
      if (query.isEmpty) return;
      _searchLocation(query);
    });
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty || _isSearchingLocation) return;
    _isSearchingLocation = true;
    try {
      final results = await locationFromAddress(query)
          .timeout(const Duration(seconds: 8));
      if (results.isEmpty) {
        _showStatusSnack("No results found.");
        _isSearchingLocation = false;
        return;
      }
      final best = results.first;
      final latLng = LatLng(best.latitude, best.longitude);
      _currentLatLng = latLng;
      _selectedMarker = Marker(
        markerId: const MarkerId("selected_location"),
        position: latLng,
      );
      if (mounted) {
        setState(() {});
      }
      _moveCamera(latLng);
    } catch (_) {
      _showStatusSnack("Unable to find that place.");
    } finally {
      _isSearchingLocation = false;
    }
  }

  Future<void> _initCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      _currentLatLng = latLng;
      if (mounted) {
        setState(() {});
      }
      _moveCamera(latLng);
    } catch (_) {
      // Keep fallback position if location cannot be resolved.
    }
  }

  void _moveCamera(LatLng latLng) {
    final controller = _mapController;
    if (!_mapReady || controller == null) return;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 16),
      ),
    );
  }

  Future<void> _goToReportWithLocation(LatLng position,
      {required String source}) async {
    if (_isResolvingLocation) return;
    _isResolvingLocation = true;
    _showStatusSnack("Resolving address...");
    final address = await _resolveAddress(position);
    final label = address.isNotEmpty
        ? address
        : "$source (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})";
    _isResolvingLocation = false;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityReportScreen(locationLabel: label),
      ),
    );
  }

  Future<String> _resolveAddress(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 8));
      if (placemarks.isEmpty) return '';
      final place = placemarks.first;
      final parts = <String>[];
      if ((place.street ?? '').trim().isNotEmpty) {
        parts.add(place.street!.trim());
      }
      if ((place.subLocality ?? '').trim().isNotEmpty) {
        parts.add(place.subLocality!.trim());
      }
      if ((place.locality ?? '').trim().isNotEmpty) {
        parts.add(place.locality!.trim());
      }
      if ((place.subAdministrativeArea ?? '').trim().isNotEmpty) {
        parts.add(place.subAdministrativeArea!.trim());
      }
      if ((place.administrativeArea ?? '').trim().isNotEmpty) {
        parts.add(place.administrativeArea!.trim());
      }
      if ((place.postalCode ?? '').trim().isNotEmpty) {
        parts.add(place.postalCode!.trim());
      }
      if ((place.country ?? '').trim().isNotEmpty) {
        parts.add(place.country!.trim());
      }
      return parts.join(', ');
    } catch (_) {
      return '';
    }
  }
  // Load custom JSON for Light Mode map
  Future<void> _loadMapStyle() async {
    // You can paste a full JSON style here or load from assets/map_style.json.
    // Light style to match the app theme.
    _mapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [{"color": "#f5f5f5"}]
      },
      {
        "elementType": "labels.icon",
        "stylers": [{"visibility": "off"}]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#616161"}]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#f5f5f5"}]
      },
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [{"color": "#c7c7c7"}]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [{"color": "#eeeeee"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry.fill",
        "stylers": [{"color": "#ffffff"}]
      },
      {
        "featureType": "road",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#616161"}]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [{"color": "#c9d9e8"}]
      }
    ]
    ''';
  }

  Set<Circle> _buildCircles(double pulseRadius) {
    return {
      // 🔴 HIGH RISK (Pulsing Animation)
      Circle(
        circleId: const CircleId('danger_zone_1'),
        center: const LatLng(37.7780, -122.4100),
        radius: pulseRadius, // Animated radius
        fillColor: const Color(0xFFE53935).withOpacity(0.3),
        strokeColor: const Color(0xFFE53935),
        strokeWidth: 2,
      ),
      // 🟠 MODERATE RISK (Static)
      Circle(
        circleId: const CircleId('moderate_zone_1'),
        center: const LatLng(37.7700, -122.4120),
        radius: 400,
        fillColor: Colors.orange.withOpacity(0.25),
        strokeColor: Colors.orange,
        strokeWidth: 1,
      ),
      // 🟢 SAFE ZONE (Static)
      Circle(
        circleId: const CircleId('safe_zone_1'),
        center: const LatLng(37.7800, -122.4250),
        radius: 500,
        fillColor: const Color(0xFF00E676).withOpacity(0.2),
        strokeColor: const Color(0xFF00E676),
        strokeWidth: 1,
      ),
    };
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dangerTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
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
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // --- The Map ---
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentLatLng ?? _fallbackPosition,
                  zoom: _currentLatLng == null ? 14.4746 : 16,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  _mapReady = true;
                  if (_mapStyle.isNotEmpty) {
                    _mapController?.setMapStyle(_mapStyle);
                  }
                  if (_currentLatLng != null) {
                    _moveCamera(_currentLatLng!);
                  }
                },
                onTap: widget.selectLocationForReport
                    ? (latLng) async {
                        _selectedMarker = Marker(
                          markerId: const MarkerId("selected_location"),
                          position: latLng,
                        );
                        _currentLatLng = latLng;
                        setState(() {});
                        await _goToReportWithLocation(
                          latLng,
                          source: "Pinned location",
                        );
                      }
                    : null,
                circles: _buildCircles(_pulseAnimation.value),
                markers:
                    _selectedMarker == null ? {} : <Marker>{_selectedMarker!},
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              );
            },
          ),

          // --- Top Overlay (Legend) ---
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              color: Colors.black54, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              onSubmitted: (value) =>
                                  _searchLocation(value.trim()),
                              style: const TextStyle(color: Colors.black87),
                              cursorColor: Colors.black54,
                              selectionHeightStyle:
                                  BoxHeightStyle.tight,
                              selectionWidthStyle:
                                  BoxWidthStyle.tight,
                              decoration: InputDecoration(
                                hintText: "Search place or address",
                                hintStyle: TextStyle(
                                    color: Colors.black54),
                                filled: true,
                                fillColor: Colors.transparent,
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.mic, color: Colors.black54),
                            onPressed: () {
                              _showStatusSnack("Voice search coming soon.");
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "Sri Lanka",
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.black54),
                              onPressed: () {
                                _searchController.clear();
                                _searchDebounce?.cancel();
                                FocusScope.of(context).unfocus();
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.black12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegendItem("High Risk", const Color(0xFFE53935)),
                      _buildLegendItem("Moderate", Colors.orange),
                      _buildLegendItem("Safe", const Color(0xFF00E676)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // --- Bottom Floating Action Buttons ---
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "recenter",
                  backgroundColor: Colors.white.withOpacity(0.95),
                  onPressed: () {
                    final current = _currentLatLng;
                    if (current != null) {
                      _moveCamera(current);
                    } else {
                      _initCurrentLocation();
                    }
                  },
                  child: const Icon(Icons.my_location, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.black87, fontSize: 12)),
      ],
    );
  }

  Widget _buildMicStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
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
