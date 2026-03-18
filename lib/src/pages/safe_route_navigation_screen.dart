import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/src/config/app_config.dart'; // For mapboxPublicToken
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

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

  Timer? _debounce;
  List<Map<String, dynamic>> _destinationSuggestions = [];
  bool _isSearchingSuggestions = false;

  LocationData? _currentPosition;
  String _distanceText = "Distance: --";
  String _durationText = "Estimated Time: --";
  bool _isCalculatingRoute = false;

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

    final resolvedLocationName = await _getReadableLocationName(
      _currentPosition!.latitude!,
      _currentPosition!.longitude!,
    );
    _sourceController.text = resolvedLocationName ??
        "${_currentPosition!.latitude}, ${_currentPosition!.longitude}";
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

  Future<void> _goToMyLocation() async {
    if (_mapController == null) return;
    if (_currentPosition == null) await _getRealLocation();
    if (_currentPosition == null) return;

    _mapController!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(
            _currentPosition!.longitude!,
            _currentPosition!.latitude!,
          ),
        ),
        zoom: _myLocationZoomOutLevel,
        pitch: 0,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<Position?> searchDestination(String place) async {
    final encodedPlace = Uri.encodeComponent(place.trim());
    final url = Uri.parse(
        "https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedPlace.json?access_token=$mapboxToken&limit=1&country=LK");

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['features'].isNotEmpty) {
        final coords = data['features'][0]['center'];
        return Position((coords[0] as num).toDouble(),
            (coords[1] as num).toDouble());
      }
    }
    return null;
  }

  Future<void> drawRoute(Position start, Position end) async {
    if (_mapController == null ||
        _polylineManager == null ||
        _circleAnnotationManager == null ||
        _pointAnnotationManager == null) return;

    final url = Uri.parse(
        "https://api.mapbox.com/directions/v5/mapbox/driving/${start.lng},${start.lat};${end.lng},${end.lat}?geometries=geojson&overview=full&alternatives=false&access_token=$mapboxToken");

    final response = await http.get(url);

    if (response.statusCode != 200) {
      _showSnackBar("Directions API failed: ${response.statusCode}");
      return;
    }

    final data = jsonDecode(response.body);
    final geometry = data['routes'][0]['geometry'];
    final routeCoordinates = (geometry['coordinates'] as List<dynamic>)
        .map((c) =>
            Position((c[0] as num).toDouble(), (c[1] as num).toDouble()))
        .toList();

    await _polylineManager!.deleteAll();
    await _circleAnnotationManager!.deleteAll();
    await _pointAnnotationManager!.deleteAll();

    // ✅ Correct usage: LineString / Point objects directly
    await _polylineManager!.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: routeCoordinates),
        lineColor: const Color(0xFF2962FF).value,
        lineWidth: 5.0,
      ),
    );

    await _circleAnnotationManager!.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: start),
        circleColor: Colors.blue.value,
        circleRadius: 8.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.value,
      ),
    );

    final ByteData bytes = await rootBundle.load('assets/red-pin bg r.png');
    final Uint8List list = bytes.buffer.asUint8List();

    await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: end),
        image: list,
        iconSize: 0.2,
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
        center: Point(coordinates: end),
        zoom: 12.5,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  @override
  Widget build(BuildContext context) {
    // your UI code here (unchanged)
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(child: Text("Map UI here")),
    );
  }
}