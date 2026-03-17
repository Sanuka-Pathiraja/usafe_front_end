import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:location/location.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/src/config/app_config.dart';
import 'dart:convert';
import 'dart:async'; // For debouncing the autocomplete
import 'package:http/http.dart' as http;

// Mapbox public token is loaded from lib/src/config/app_config.dart (gitignored)
const String mapboxToken = mapboxPublicToken;

class SafeRouteNavigationScreen extends StatefulWidget {
  const SafeRouteNavigationScreen({super.key});

  @override
  State<SafeRouteNavigationScreen> createState() =>
      _SafeRouteNavigationScreenState();
}

class _SafeRouteNavigationScreenState extends State<SafeRouteNavigationScreen> {
  MapboxMap? _mapController;
  PolylineAnnotationManager? _polylineManager;
  CircleAnnotationManager? _circleAnnotationManager;
  PointAnnotationManager? _pointAnnotationManager;
  static const double _myLocationZoomOutLevel = 10.5;

  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final Location _location = Location();

  // Autocomplete state...
  Timer? _debounce;
  List<Map<String, dynamic>> _destinationSuggestions = [];
  bool _isSearchingSuggestions = false;

  LocationData? _currentPosition;
  String _distanceText = "Distance: --";
  String _durationText = "Estimated Time: --";

  @override
  void dispose() {
    _debounce?.cancel();
    _sourceController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ____________ GET REAL LOCATION_______________
  Future<void> _getRealLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != PermissionStatus.granted) return;
    }

    _currentPosition = await _location.getLocation();

    // AUTO FILL SOURCE FIELD
    final resolvedLocationName = await _getReadableLocationName(
      _currentPosition!.latitude!,
      _currentPosition!.longitude!,
    );
    _sourceController.text = resolvedLocationName ??
        "${_currentPosition!.latitude}, ${_currentPosition!.longitude}";

    print(
        "My Real Location = ${_currentPosition!.latitude}, ${_currentPosition!.longitude}");
  }

  Future<String?> _getReadableLocationName(double lat, double lng) async {
    final url = Uri.parse(
      "https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json"
      "?access_token=$mapboxToken&types=address,place,locality,neighborhood&limit=1",
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final features = data["features"] as List<dynamic>?;
    if (features == null || features.isEmpty) return null;

    return features.first["place_name"] as String?;
  }

  // ____________ MAPBOX: GO TO MY LOCATION _______________
  Future<void> _goToMyLocation() async {
    if (_mapController == null) return;

    if (_currentPosition == null) {
      await _getRealLocation();
    }

    if (_currentPosition != null) {
      // Moves the camera on the current map instance (does not open a new map).
      _mapController!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude!,
              _currentPosition!.latitude!,
            ),
          ).toJson(),
          zoom: _myLocationZoomOutLevel,
          pitch: 0,
          bearing: 0,
        ),
        MapAnimationOptions(duration: 1000),
      );
      print("Moved camera to my location (zoomed out)");
    }
  }

  //Search for destination using Mapbox Geocoding API
  Future<Position?> searchDestination(String place) async {
    final encodedPlace = Uri.encodeComponent(place.trim());
    final url = Uri.parse(
        "https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedPlace.json?access_token=$mapboxToken&limit=1&country=LK");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['features'].isNotEmpty) {
        final coords = data['features'][0]['center'];
        return Position(
            (coords[0] as num).toDouble(), (coords[1] as num).toDouble());
      }
    }

    return null;
  }

  // __________ FETCH DESTINATION SUGGESTIONS (AUTOCOMPLETE) __________
  Future<void> fetchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _destinationSuggestions = [];
      });
      return;
    }

    setState(() {
      _isSearchingSuggestions = true;
    });

    final encodedQuery = Uri.encodeComponent(query.trim());
    // Limit to 5 suggestions, inside Sri Lanka
    final url = Uri.parse(
        "https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json?access_token=$mapboxToken&limit=5&country=LK&types=place,locality,neighborhood,address,poi");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>?;

        if (features != null && mounted) {
          setState(() {
            _destinationSuggestions =
                features.map((f) => f as Map<String, dynamic>).toList();
          });
        }
      }
    } catch (e) {
      print("Error fetching suggestions: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingSuggestions = false;
        });
      }
    }
  }

// __________ DRAW ROUTE USING MAPBOX DIRECTIONS API __________

  Future<void> drawRoute(Position start, Position end) async {
    if (_mapController == null ||
        _polylineManager == null ||
        _circleAnnotationManager == null ||
        _pointAnnotationManager == null) return;

    final url = Uri.parse("https://api.mapbox.com/directions/v5/mapbox/driving/"
        "${start.lng},${start.lat};${end.lng},${end.lat}"
        "?geometries=geojson&overview=full&alternatives=false&access_token=$mapboxToken");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['routes'] == null || (data['routes'] as List).isEmpty) {
        _showSnackBar("No route found.");
        return;
      }

      final geometry = data['routes'][0]['geometry'];
      final routeCoordinates = (geometry['coordinates'] as List<dynamic>)
          .map((c) =>
              Position((c[0] as num).toDouble(), (c[1] as num).toDouble()))
          .toList();

      await _polylineManager!.deleteAll();
      await _circleAnnotationManager!.deleteAll();
      await _pointAnnotationManager!.deleteAll();

      // Draw Route Polyline
      await _polylineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: routeCoordinates).toJson(),
          lineColor: const Color(0xFF2962FF).value,
          lineWidth: 5.0,
        ),
      );

      // --- ADD MARKERS ---
      // Start Marker (Blue Dot)
      await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: start).toJson(),
          circleColor: Colors.blue.value,
          circleRadius: 8.0,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        ),
      );

      // Destination Marker (Red Pin Icon)
      final ByteData bytes = await rootBundle.load('assets/red-pin bg r.png');
      final Uint8List list = bytes.buffer.asUint8List();

      await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: end).toJson(),
          image: list,
          iconSize: 0.2, // Adjust size as needed
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );

      final routeDistanceMeters =
          (data['routes'][0]['distance'] as num?)?.toDouble() ?? 0.0;
      final routeDurationSeconds =
          (data['routes'][0]['duration'] as num?)?.toDouble() ?? 0.0;

      if (mounted) {
        setState(() {
          _distanceText =
              "Distance: ${(routeDistanceMeters / 1000).toStringAsFixed(1)} km";
          _durationText =
              "Estimated Time: ${(routeDurationSeconds / 60).toStringAsFixed(0)} mins";
        });
      }

      await _mapController!.flyTo(
        CameraOptions(
          center: Point(coordinates: end).toJson(),
          zoom: 12.5,
        ),
        MapAnimationOptions(duration: 1200),
      );
    } else {
      _showSnackBar("Directions API failed: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Safe Route Navigation"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ---------------- MAPBOX MAP ----------------
          MapWidget(
            key: const ValueKey("mapbox_map"),
            cameraOptions: CameraOptions(
              center: Point(
                // 🇱🇰 CENTER OF SRI LANKA
                coordinates: Position(80.7718, 7.8731),
              ).toJson(),
              zoom: 7, // zoomed out to show whole Sri Lanka
            ),
            onMapCreated: (map) async {
              _mapController = map;
              _polylineManager =
                  await map.annotations.createPolylineAnnotationManager();
              _circleAnnotationManager =
                  await map.annotations.createCircleAnnotationManager();
              _pointAnnotationManager =
                  await map.annotations.createPointAnnotationManager();
              await _getRealLocation();
            },
          ),

          // ---------------- SEARCH PANEL ----------------
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _sourceController,
                        decoration: const InputDecoration(
                          hintText: "Your Location",
                          prefixIcon:
                              Icon(Icons.circle, size: 12, color: Colors.green),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const Divider(
                          height: 1, thickness: 1, color: Colors.black12),
                      TextField(
                        controller: _destinationController,
                        onChanged: (value) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce =
                              Timer(const Duration(milliseconds: 500), () {
                            fetchSuggestions(value);
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: "Enter Destination",
                          prefixIcon:
                              Icon(Icons.location_on, color: Colors.red),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      // ---------------- AUTOCOMPLETE SUGGESTIONS ----------------
                      if (_isSearchingSuggestions)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      if (_destinationSuggestions.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: const BoxDecoration(
                            border:
                                Border(top: BorderSide(color: Colors.black12)),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _destinationSuggestions.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final suggestion = _destinationSuggestions[index];
                              return ListTile(
                                leading: const Icon(Icons.place,
                                    color: Colors.blueAccent),
                                title: Text(
                                  suggestion['place_name'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                onTap: () {
                                  _destinationController.text =
                                      suggestion['place_name'] ?? '';
                                  setState(() {
                                    _destinationSuggestions = [];
                                  });
                                  FocusScope.of(context)
                                      .unfocus(); // dismiss keyboard
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 3,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      try {
                        if (_currentPosition == null) {
                          await _getRealLocation();
                        }

                        if (_currentPosition == null) {
                          _showSnackBar("Current location unavailable.");
                          return;
                        }

                        final destinationText = _destinationController.text;
                        if (destinationText.trim().isEmpty) {
                          _showSnackBar("Please enter a destination.");
                          return;
                        }

                        final destination =
                            await searchDestination(destinationText);
                        if (destination == null) {
                          _showSnackBar(
                              "Destination not found. Try a Sri Lanka place name.");
                          return;
                        }

                        final start = Position(
                          _currentPosition!.longitude!,
                          _currentPosition!.latitude!,
                        );

                        await drawRoute(start, destination);
                      } catch (e) {
                        _showSnackBar("Route error: $e");
                      }
                    },
                    child: const Text(
                      "Find Route",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------------- DRAGGABLE PANEL ----------------
          DraggableScrollableSheet(
            initialChildSize: 0.12,
            minChildSize: 0.12,
            maxChildSize: 0.45,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(top: 10, bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const Text(
                      "Route Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_distanceText,
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(_durationText,
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text("Safety Score: High Safety Area",
                              style: TextStyle(
                                  color: Colors.greenAccent, fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2962FF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Start Navigation",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // __________ SOS BUTTON __________
          Positioned(
            bottom: 50,
            left: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              heroTag: "sos_button",
              onPressed: () {
                print("SOS clicked");
              },
              child: const Icon(Icons.warning, size: 28),
            ),
          ),

          // __________ MY LOCATION BUTTON __________
          Positioned(
            bottom: 50,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blueAccent,
              heroTag: "my_location_button",
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
