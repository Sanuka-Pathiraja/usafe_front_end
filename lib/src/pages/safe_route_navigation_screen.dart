import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/src/config/app_config.dart'; // For mapboxPublicToken
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
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
  PointAnnotationManager? _pointAnnotationManager;
  CircleAnnotationManager? _userLocationManager;
  CircleAnnotation? _userLocationAnnotation;
  static const double _myLocationZoomOutLevel = 14.5;

  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final Location _location = Location();

  Timer? _debounce;
  List<Map<String, dynamic>> _destinationSuggestions = [];
  bool _isSearchingSuggestions = false;
  String _searchSessionToken = '';
  String? _selectedDestinationMapboxId;
  Position? _selectedDestinationPosition;

  LocationData? _currentPosition;
  String _distanceText = "Distance: --";
  String _durationText = "Estimated Time: --";
  bool _isCalculatingRoute = false;
  StreamSubscription<LocationData>? _locationSubscription;

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _debounce?.cancel();
    _sourceController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refreshSearchSessionToken();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _refreshSearchSessionToken() {
    final random = Random.secure();
    final bytes =
        List<int>.generate(16, (_) => random.nextInt(256)).map((value) {
      return value.toRadixString(16).padLeft(2, '0');
    }).join();
    _searchSessionToken =
        '${bytes.substring(0, 8)}-${bytes.substring(8, 12)}-${bytes.substring(12, 16)}-${bytes.substring(16, 20)}-${bytes.substring(20, 32)}';
  }

  String _buildSearchBoxCommonParams() {
    final params = <String>[
      'access_token=$mapboxToken',
      'session_token=$_searchSessionToken',
      'limit=10',
      'language=en',
      'country=LK',
    ];

    if (_currentPosition?.longitude != null &&
        _currentPosition?.latitude != null) {
      params.add(
        'proximity=${_currentPosition!.longitude},${_currentPosition!.latitude}',
      );
    }

    return params.join('&');
  }

  Position _positionFromLocation(LocationData location) {
    return Position(location.longitude!, location.latitude!);
  }

  CircleAnnotationOptions _buildUserLocationMarker(Position position) {
    return CircleAnnotationOptions(
      geometry: Point(coordinates: position),
      circleColor: Colors.blue.value,
      circleRadius: 8.0,
      circleStrokeWidth: 2.0,
      circleStrokeColor: Colors.white.value,
      circleSortKey: 100,
    );
  }

  Future<bool> _ensureLocationAccess() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }

    return permission == PermissionStatus.granted;
  }

  Future<void> _moveCameraToPosition(
    Position position, {
    double zoom = _myLocationZoomOutLevel,
  }) async {
    if (_mapController == null) return;

    await _mapController!.flyTo(
      CameraOptions(
        center: Point(coordinates: position),
        zoom: zoom,
        pitch: 0,
        bearing: 0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _syncUserLocationMarker({
    required LocationData location,
    bool moveCamera = false,
  }) async {
    if (_userLocationManager == null ||
        location.latitude == null ||
        location.longitude == null) {
      return;
    }

    final position = _positionFromLocation(location);

    if (_userLocationAnnotation == null) {
      _userLocationAnnotation = await _userLocationManager!
          .create(_buildUserLocationMarker(position));
    } else {
      _userLocationAnnotation!.geometry = Point(coordinates: position);
      await _userLocationManager!.update(_userLocationAnnotation!);
    }

    if (moveCamera) {
      await _moveCameraToPosition(position);
    }
  }

  Future<void> _startUserLocationTracking() async {
    final hasAccess = await _ensureLocationAccess();
    if (!hasAccess) return;

    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 2000,
      distanceFilter: 5,
    );

    final initialLocation = await _location.getLocation();
    _currentPosition = initialLocation;
    await _syncUserLocationMarker(location: initialLocation, moveCamera: true);
    await _updateSourceLabel();

    _locationSubscription?.cancel();
    _locationSubscription =
        _location.onLocationChanged.listen((location) async {
      if (!mounted || location.latitude == null || location.longitude == null) {
        return;
      }

      _currentPosition = location;
      await _syncUserLocationMarker(location: location);
    });
  }

  Future<void> _getRealLocation() async {
    final hasAccess = await _ensureLocationAccess();
    if (!hasAccess) return;

    _currentPosition = await _location.getLocation();
    await _syncUserLocationMarker(location: _currentPosition!);
    await _updateSourceLabel();
  }

  Future<void> _updateSourceLabel() async {
    if (_currentPosition?.latitude == null ||
        _currentPosition?.longitude == null) {
      return;
    }

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

    await _moveCameraToPosition(
      Position(
        _currentPosition!.longitude!,
        _currentPosition!.latitude!,
      ),
    );
  }

  Future<void> fetchSuggestions(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      if (!mounted) return;
      setState(() {
        _destinationSuggestions = [];
        _isSearchingSuggestions = false;
        _selectedDestinationMapboxId = null;
        _selectedDestinationPosition = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isSearchingSuggestions = true);

    try {
      var parsedSuggestions = <Map<String, dynamic>>[];

      final geocodingSuggestion =
          await _geocodingFallbackSuggestion(trimmedQuery);
      if (geocodingSuggestion != null) {
        parsedSuggestions = [geocodingSuggestion];
      } else {
        final url = Uri.parse(
          "https://api.mapbox.com/search/searchbox/v1/suggest"
          "?q=${Uri.encodeComponent(trimmedQuery)}&${_buildSearchBoxCommonParams()}",
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final suggestions = data['suggestions'];
          parsedSuggestions = suggestions is List
              ? suggestions
                  .whereType<Map>()
                  .map((feature) => Map<String, dynamic>.from(feature))
                  .toList()
              : <Map<String, dynamic>>[];
        }
      }

      if (!mounted) return;
      setState(() {
        _destinationSuggestions = parsedSuggestions;
      });
    } catch (e) {
      debugPrint("Suggestions Error: $e");
      if (!mounted) return;
      setState(() => _destinationSuggestions = []);
    } finally {
      if (!mounted) return;
      setState(() => _isSearchingSuggestions = false);
    }
  }

  Future<Map<String, dynamic>?> _retrieveSuggestion(String mapboxId) async {
    final url = Uri.parse(
      "https://api.mapbox.com/search/searchbox/v1/retrieve/"
      "$mapboxId?access_token=$mapboxToken&session_token=$_searchSessionToken&language=en",
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final features = data['features'];
    if (features is! List || features.isEmpty) return null;

    final feature = features.first;
    return feature is Map<String, dynamic>
        ? feature
        : Map<String, dynamic>.from(feature as Map);
  }

  Future<Position?> _forwardSearchDestination(String place) async {
    final params = <String>[
      'access_token=$mapboxToken',
      'limit=1',
      'language=en',
      'autocomplete=true',
      'country=LK',
    ];

    if (_currentPosition?.longitude != null &&
        _currentPosition?.latitude != null) {
      params.add(
        'proximity=${_currentPosition!.longitude},${_currentPosition!.latitude}',
      );
    }

    final url = Uri.parse(
      "https://api.mapbox.com/search/searchbox/v1/forward"
      "?q=${Uri.encodeComponent(place.trim())}&${params.join('&')}",
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final features = data['features'];
    if (features is! List || features.isEmpty) return null;

    final feature = features.first;
    final featureMap = feature is Map<String, dynamic>
        ? feature
        : Map<String, dynamic>.from(feature as Map);
    final geometry = featureMap['geometry'];
    final coordinates =
        geometry is Map<String, dynamic> ? geometry['coordinates'] : null;
    if (coordinates is List && coordinates.length >= 2) {
      return Position(
        (coordinates[0] as num).toDouble(),
        (coordinates[1] as num).toDouble(),
      );
    }

    return null;
  }

  Future<Position?> _geocodingFallbackDestination(String place) async {
    try {
      final results = await geocoding
          .locationFromAddress(place.trim())
          .timeout(const Duration(seconds: 8));
      if (results.isEmpty) return null;

      final best = results.first;
      return Position(best.longitude, best.latitude);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _geocodingFallbackSuggestion(
    String place,
  ) async {
    try {
      final results = await geocoding
          .locationFromAddress(place.trim())
          .timeout(const Duration(seconds: 8));
      if (results.isEmpty) return null;

      final best = results.first;
      return <String, dynamic>{
        'name': place.trim(),
        'full_address': place.trim(),
        'feature_type': 'place',
        'source': 'geocoding_fallback',
        'fallback_lat': best.latitude,
        'fallback_lng': best.longitude,
      };
    } catch (_) {
      return null;
    }
  }

  Future<Position?> searchDestination(String place) async {
    if (_selectedDestinationPosition != null) {
      return _selectedDestinationPosition;
    }

    final geocodingPosition = await _geocodingFallbackDestination(place);
    if (geocodingPosition != null) {
      return geocodingPosition;
    }

    var mapboxId = _selectedDestinationMapboxId;

    if (mapboxId == null || mapboxId.isEmpty) {
      final suggestUrl = Uri.parse(
        "https://api.mapbox.com/search/searchbox/v1/suggest"
        "?q=${Uri.encodeComponent(place.trim())}&${_buildSearchBoxCommonParams()}",
      );
      final suggestResponse = await http.get(suggestUrl);
      if (suggestResponse.statusCode != 200) {
        return _forwardSearchDestination(place) ??
            _geocodingFallbackDestination(place);
      }

      final suggestData =
          jsonDecode(suggestResponse.body) as Map<String, dynamic>;
      final suggestions = suggestData['suggestions'];
      if (suggestions is! List || suggestions.isEmpty) {
        return _forwardSearchDestination(place) ??
            _geocodingFallbackDestination(place);
      }
      mapboxId = suggestions.first['mapbox_id']?.toString();
    }

    if (mapboxId == null || mapboxId.isEmpty) {
      return _forwardSearchDestination(place) ??
          _geocodingFallbackDestination(place);
    }

    final feature = await _retrieveSuggestion(mapboxId);
    if (feature == null) {
      return _forwardSearchDestination(place) ??
          _geocodingFallbackDestination(place);
    }

    final geometry = feature['geometry'];
    final coordinates =
        geometry is Map<String, dynamic> ? geometry['coordinates'] : null;
    if (coordinates is List && coordinates.length >= 2) {
      return Position(
        (coordinates[0] as num).toDouble(),
        (coordinates[1] as num).toDouble(),
      );
    }

    return _forwardSearchDestination(place) ??
        _geocodingFallbackDestination(place);
  }

  Future<void> drawRoute(Position start, Position end) async {
    if (_mapController == null ||
        _polylineManager == null ||
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
        .map(
            (c) => Position((c[0] as num).toDouble(), (c[1] as num).toDouble()))
        .toList();

    await _polylineManager!.deleteAll();
    await _pointAnnotationManager!.deleteAll();

    await _polylineManager!.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: routeCoordinates),
        lineColor: const Color(0xFF2962FF).value,
        lineWidth: 5.0,
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

  // __________ CLEAR ROUTE __________
  Future<void> _clearRoute() async {
    await _polylineManager?.deleteAll();
    await _pointAnnotationManager?.deleteAll();

    if (mounted) {
      setState(() {
        _destinationController.clear();
        _destinationSuggestions = [];
        _distanceText = "Distance: --";
        _durationText = "Estimated Time: --";
      });
    }
  }

  IconData _getIconForType(List<dynamic>? types) {
    if (types == null || types.isEmpty) return Icons.location_on;
    if (types.contains('poi')) return Icons.place;
    if (types.contains('address')) return Icons.home_outlined;
    if (types.contains('locality')) return Icons.location_city;
    if (types.contains('place')) return Icons.map_outlined;
    return Icons.location_on;
  }

  List<dynamic>? _suggestionTypes(Map<String, dynamic> suggestion) {
    final featureType = suggestion['feature_type']?.toString();
    final poiCategory = suggestion['poi_category'];

    if (poiCategory is List && poiCategory.isNotEmpty) {
      return ['poi', ...poiCategory];
    }
    if (featureType == null || featureType.isEmpty) return null;
    return [featureType];
  }

  String _suggestionLabel(Map<String, dynamic> suggestion) {
    final name = suggestion['name']?.toString().trim() ?? '';
    final address = suggestion['full_address']?.toString().trim() ?? '';
    if (address.isEmpty) return name;
    if (name.isEmpty) return address;
    if (address.startsWith(name)) return address;
    return '$name, $address';
  }

  String _formatPlaceType(List<dynamic>? types) {
    if (types == null || types.isEmpty) return 'Location';
    return types
        .whereType<String>()
        .map((type) => type.replaceAll('_', ' '))
        .map(
          (type) => type.isEmpty
              ? type
              : "${type[0].toUpperCase()}${type.substring(1)}",
        )
        .join(', ');
  }

  Text _buildRichText(String fullText, String query) {
    return Text(
      fullText,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // your UI code here (unchanged)
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
            styleUri: MapboxStyles.STANDARD,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(80.7718, 7.8731),
              ),
              zoom: 7,
            ),
            onTapListener: (_) async {
              FocusScope.of(context).unfocus();
            },
            onMapCreated: (map) async {
              _mapController = map;
              _polylineManager =
                  await map.annotations.createPolylineAnnotationManager();
              _pointAnnotationManager =
                  await map.annotations.createPointAnnotationManager();
              _userLocationManager =
                  await map.annotations.createCircleAnnotationManager();

              await _startUserLocationTracking();
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
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _destinationController,
                        onChanged: (value) {
                          _selectedDestinationMapboxId = null;
                          _selectedDestinationPosition = null;
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
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _destinationSuggestions.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final suggestion =
                                    _destinationSuggestions[index];
                                final types = _suggestionTypes(suggestion);

                                return TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 400),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 10 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2962FF)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _getIconForType(types),
                                        color: const Color(0xFF2962FF),
                                        size: 20,
                                      ),
                                    ),
                                    title: _buildRichText(
                                      _suggestionLabel(suggestion),
                                      _destinationController.text,
                                    ),
                                    subtitle: Text(
                                      _formatPlaceType(types),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    onTap: () {
                                      _selectedDestinationMapboxId =
                                          suggestion['mapbox_id']?.toString();
                                      final fallbackLat =
                                          suggestion['fallback_lat'];
                                      final fallbackLng =
                                          suggestion['fallback_lng'];
                                      _selectedDestinationPosition =
                                          fallbackLat is num &&
                                                  fallbackLng is num
                                              ? Position(
                                                  fallbackLng.toDouble(),
                                                  fallbackLat.toDouble(),
                                                )
                                              : null;
                                      _destinationController.text =
                                          _suggestionLabel(suggestion);
                                      setState(() {
                                        _destinationSuggestions = [];
                                      });
                                      _refreshSearchSessionToken();
                                      FocusScope.of(context).unfocus();
                                    },
                                  ),
                                );
                              },
                            ),
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
                    onPressed: _isCalculatingRoute
                        ? null
                        : () async {
                            FocusScope.of(context).unfocus();
                            setState(() => _isCalculatingRoute = true);
                            try {
                              if (_currentPosition == null) {
                                await _getRealLocation();
                              }
                              if (_currentPosition == null) {
                                _showSnackBar("Current location unavailable.");
                                return;
                              }
                              final destinationText =
                                  _destinationController.text;
                              if (destinationText.trim().isEmpty) {
                                _showSnackBar("Please enter a destination.");
                                return;
                              }
                              final destination =
                                  await searchDestination(destinationText);
                              if (destination == null) {
                                _showSnackBar("Destination not found.");
                                return;
                              }
                              await drawRoute(
                                Position(_currentPosition!.longitude!,
                                    _currentPosition!.latitude!),
                                destination,
                              );
                            } catch (e) {
                              _showSnackBar("Route error: $e");
                            } finally {
                              if (mounted) {
                                setState(() => _isCalculatingRoute = false);
                              }
                            }
                          },
                    child: _isCalculatingRoute
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2962FF)),
                            ),
                          )
                        : const Text(
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
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(_durationText,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16)),
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
              onPressed: () {},
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
