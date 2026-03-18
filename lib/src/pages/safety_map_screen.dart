import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SafetyMapScreen extends StatefulWidget {
  const SafetyMapScreen({Key? key}) : super(key: key);

  @override
  _SafetyMapScreenState createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> with SingleTickerProviderStateMixin {
  late GoogleMapController _mapController;
  String _darkMapStyle = '';

  // Initial Camera Position (San Francisco placeholder)
  static final CameraPosition _kInitialPosition = const CameraPosition(
    target: LatLng(37.7749, -122.4194),
    zoom: 14.0,
  );


  @override
  void initState() {
    super.initState();
    // Prepare the dark map styling.
    _loadMapStyle();
  }

  // Load custom JSON for Dark Mode map
  Future<void> _loadMapStyle() async {
    // You can paste a full JSON style here or load from assets/map_style.json
    // For now, this is a simplified dark style string
    _darkMapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [{"color": "#212121"}]
      },
      {
        "elementType": "labels.icon",
        "stylers": [{"visibility": "off"}]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#757575"}]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#212121"}]
      },
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [{"color": "#757575"}]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [{"color": "#181818"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry.fill",
        "stylers": [{"color": "#2c2c2c"}]
      },
      {
        "featureType": "road",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#8a8a8a"}]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [{"color": "#000000"}]
      }
    ]
    ''';
  }

  Set<Circle> _buildCircles() {
    return {};
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // --- The Map ---
          GoogleMap(
            initialCameraPosition: _kInitialPosition,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              if (_darkMapStyle.isNotEmpty) {
                _mapController.setMapStyle(_darkMapStyle);
              }
            },
            circles: _buildCircles(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // --- Bottom Floating Action Buttons ---
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "recenter",
                  backgroundColor: const Color(0xFF1E1E1E),
                  onPressed: () {
                    // TODO: implement re-center to current location.
                  },
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
                const SizedBox(height: 16),
                FloatingActionButton.extended(
                  heroTag: "report",
                  backgroundColor: const Color(0xFFE53935),
                  onPressed: () {
                    // TODO: navigate to a report flow.
                  },
                  icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  label: const Text("Report Incident", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
