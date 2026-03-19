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
  late final Widget _mapView;

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
  int _suggestionRequestId = 0;
  bool _isPickingDestination = false;
  Position? _pendingPinnedPosition;
  Position? _confirmedPinnedPosition;
  Uint8List? _destinationMarkerBytes;
  double _sheetExtent = 0.12;

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _debounce?.cancel();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refreshSearchSessionToken();
    _mapView = RepaintBoundary(
      child: MapWidget(
        key: const ValueKey("mapbox_map"),
        styleUri: MapboxStyles.STANDARD,
        cameraOptions: CameraOptions(
          center: Point(
            coordinates: Position(80.7718, 7.8731),
          ),
          zoom: 7,
        ),
        onTapListener: (_) async {
          if (!mounted) return;
          FocusScope.of(context).unfocus();
        },
        onCameraChangeListener: (event) {
          if (!_isPickingDestination) return;
          _pendingPinnedPosition = _positionFromPoint(event.cameraState.center);
        },
        onMapIdleListener: (_) {
          if (!mounted || !_isPickingDestination) return;
          setState(() {});
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
    );
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

    if (_currentPosition?.longitude != null && _currentPosition?.latitude != null) {
      params.add(
        'proximity=${_currentPosition!.longitude},${_currentPosition!.latitude}',
      );
    }

    return params.join('&');
  }

  Position _positionFromLocation(LocationData location) {
    return Position(location.longitude!, location.latitude!);
  }

  Position _positionFromPoint(Point point) {
    return point.coordinates;
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
      _userLocationAnnotation =
          await _userLocationManager!.create(_buildUserLocationMarker(position));
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

  String _pinnedLocationLabel(Position position) {
    return 'Pinned point (${position.lat.toStringAsFixed(5)}, ${position.lng.toStringAsFixed(5)})';
  }

  Future<Uint8List> _loadDestinationMarkerBytes() async {
    final existing = _destinationMarkerBytes;
    if (existing != null) {
      return existing;
    }

    final bytes = await rootBundle.load('assets/red-pin bg r.png');
    final markerBytes = bytes.buffer.asUint8List();
    _destinationMarkerBytes = markerBytes;
    return markerBytes;
  }

  Future<void> _showDestinationPin(Position position) async {
    final pointManager = _pointAnnotationManager;
    if (pointManager == null) return;

    await pointManager.deleteAll();
    final markerBytes = await _loadDestinationMarkerBytes();
    await pointManager.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: position),
        image: markerBytes,
        iconSize: 0.2,
        iconAnchor: IconAnchor.BOTTOM,
      ),
    );
  }

  Future<void> _enableMapPickMode() async {
    FocusScope.of(context).unfocus();

    Position? initialPin = _confirmedPinnedPosition ?? _selectedDestinationPosition;
    if (initialPin == null && _currentPosition != null) {
      initialPin = Position(
        _currentPosition!.longitude!,
        _currentPosition!.latitude!,
      );
    }

    if (initialPin != null) {
      _pendingPinnedPosition = initialPin;
      await _moveCameraToPosition(initialPin);
    } else if (_mapController != null) {
      final cameraState = await _mapController!.getCameraState();
      _pendingPinnedPosition = _positionFromPoint(cameraState.center);
    }

    if (!mounted) return;
    setState(() {
      _isPickingDestination = true;
    });
  }

  void _cancelMapPickMode() {
    if (!mounted) return;
    setState(() {
      _isPickingDestination = false;
      _pendingPinnedPosition = null;
    });
  }

  Future<void> _confirmPinnedDestination() async {
    Position? position = _pendingPinnedPosition;

    if (position == null && _mapController != null) {
      final cameraState = await _mapController!.getCameraState();
      position = _positionFromPoint(cameraState.center);
    }

    if (position == null) {
      _showSnackBar('Move the map to choose a destination.');
      return;
    }

    final confirmedPosition = position;

    await _showDestinationPin(confirmedPosition);

    if (!mounted) return;
    setState(() {
      _confirmedPinnedPosition = confirmedPosition;
      _selectedDestinationPosition = confirmedPosition;
      _selectedDestinationMapboxId = null;
      _destinationSuggestions = [];
      _destinationController.text = _pinnedLocationLabel(confirmedPosition);
      _isPickingDestination = false;
      _pendingPinnedPosition = null;
    });
  }

  Future<void> _handleFindRoute() async {
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
      final destinationText = _destinationController.text;
      if (destinationText.trim().isEmpty) {
        _showSnackBar("Please enter a destination.");
        return;
      }
      final destination = await searchDestination(destinationText);
      if (destination == null) {
        _showSnackBar("Destination not found.");
        return;
      }
      await drawRoute(
        Position(
          _currentPosition!.longitude!,
          _currentPosition!.latitude!,
        ),
        destination,
      );
    } catch (e) {
      _showSnackBar("Route error: $e");
    } finally {
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
      }
    }
  }

  Future<void> fetchSuggestions(String query) async {
    final trimmedQuery = query.trim();
    final requestId = ++_suggestionRequestId;

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

      if (!mounted || requestId != _suggestionRequestId) return;
      setState(() {
        _destinationSuggestions = parsedSuggestions;
      });
    } catch (e) {
      debugPrint("Suggestions Error: $e");
      if (!mounted || requestId != _suggestionRequestId) return;
      setState(() => _destinationSuggestions = []);
    } finally {
      if (!mounted || requestId != _suggestionRequestId) return;
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

    if (_currentPosition?.longitude != null && _currentPosition?.latitude != null) {
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
      final results = await geocoding.locationFromAddress(place.trim())
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
      final results = await geocoding.locationFromAddress(place.trim())
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

    var mapboxId = _selectedDestinationMapboxId;

    if (mapboxId == null || mapboxId.isEmpty) {
      final suggestUrl = Uri.parse(
        "https://api.mapbox.com/search/searchbox/v1/suggest"
        "?q=${Uri.encodeComponent(place.trim())}&${_buildSearchBoxCommonParams()}",
      );
      final suggestResponse = await http.get(suggestUrl);
      if (suggestResponse.statusCode != 200) {
        return await _resolveDestinationFallback(place);
      }

      final suggestData = jsonDecode(suggestResponse.body) as Map<String, dynamic>;
      final suggestions = suggestData['suggestions'];
      if (suggestions is! List || suggestions.isEmpty) {
        return await _resolveDestinationFallback(place);
      }
      mapboxId = suggestions.first['mapbox_id']?.toString();
    }

    if (mapboxId == null || mapboxId.isEmpty) {
      return await _resolveDestinationFallback(place);
    }

    final feature = await _retrieveSuggestion(mapboxId);
    if (feature == null) {
      return await _resolveDestinationFallback(place);
    }

    final geometry = feature['geometry'];
    final coordinates = geometry is Map<String, dynamic> ? geometry['coordinates'] : null;
    if (coordinates is List && coordinates.length >= 2) {
      return Position(
        (coordinates[0] as num).toDouble(),
        (coordinates[1] as num).toDouble(),
      );
    }

    return await _resolveDestinationFallback(place);
  }

  Future<Position?> _resolveDestinationFallback(String place) async {
    final forwardPosition = await _forwardSearchDestination(place);
    if (forwardPosition != null) {
      return forwardPosition;
    }

    return _geocodingFallbackDestination(place);
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
        .map((c) =>
            Position((c[0] as num).toDouble(), (c[1] as num).toDouble()))
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

    final Uint8List list = await _loadDestinationMarkerBytes();

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
        _confirmedPinnedPosition = end;
        _selectedDestinationPosition = end;
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
        _selectedDestinationMapboxId = null;
        _selectedDestinationPosition = null;
        _confirmedPinnedPosition = null;
        _pendingPinnedPosition = null;
        _isPickingDestination = false;
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
          _mapView,

          // ---------------- SEARCH PANEL ----------------
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF102348).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _destinationController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            onChanged: (value) {
                              _selectedDestinationMapboxId = null;
                              _selectedDestinationPosition = null;
                              _confirmedPinnedPosition = null;
                              if (_debounce?.isActive ?? false) {
                                _debounce!.cancel();
                              }
                              _debounce =
                                  Timer(const Duration(milliseconds: 500), () {
                                fetchSuggestions(value);
                              });
                            },
                            decoration: InputDecoration(
                              hintText: "Enter destination",
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.62),
                              ),
                              prefixIcon: const Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFFFF6B57),
                              ),
                              suffixIcon: _destinationController.text.isEmpty
                                  ? IconButton(
                                      onPressed: _isCalculatingRoute
                                          ? null
                                          : _handleFindRoute,
                                      icon: Icon(
                                        Icons.search_rounded,
                                        color: Colors.white.withOpacity(0.72),
                                        size: 19,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: _isCalculatingRoute
                                              ? null
                                              : _handleFindRoute,
                                          icon: Icon(
                                            Icons.search_rounded,
                                            color:
                                                Colors.white.withOpacity(0.72),
                                            size: 19,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: _clearRoute,
                                          icon: Icon(
                                            Icons.close_rounded,
                                            color:
                                                Colors.white.withOpacity(0.62),
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                          ),
                          if (_isSearchingSuggestions)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          if (_destinationSuggestions.isNotEmpty)
                            Container(
                              constraints: const BoxConstraints(maxHeight: 220),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
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

                                  return ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2962FF)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
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
                                    onTap: () async {
                                      _selectedDestinationMapboxId =
                                          suggestion['mapbox_id']?.toString();
                                      final fallbackLat =
                                          suggestion['fallback_lat'];
                                      final fallbackLng =
                                          suggestion['fallback_lng'];
                                      _confirmedPinnedPosition = null;
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
                                      await _handleFindRoute();
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_confirmedPinnedPosition != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.place_rounded,
                              color: Colors.white.withOpacity(0.72),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _pinnedLocationLabel(_confirmedPinnedPosition!),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          if (_isPickingDestination)
            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: const Icon(
                    Icons.location_on_rounded,
                    size: 52,
                    color: Colors.red,
                  ),
                ),
              ),
            ),

          if (_isPickingDestination)
            Positioned(
              left: 16,
              right: 16,
              bottom: 232,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFCFD),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withOpacity(0.04)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF3FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.push_pin_rounded,
                            color: Color(0xFF2F6BFF),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Pick Destination',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _pendingPinnedPosition == null
                          ? 'Drag the map until the pin is over your destination.'
                          : _pinnedLocationLabel(_pendingPinnedPosition!),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirmPinnedDestination,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2962FF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Pin This Location',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 16,
            right: 16,
            bottom: _sheetExtent > 0.17 ? 104 : 136,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _sheetExtent > 0.17 ? 0 : 1,
              child: IgnorePointer(
                ignoring: _sheetExtent > 0.17,
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E63FF),
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: Colors.black.withOpacity(0.18),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _isCalculatingRoute ? null : _handleFindRoute,
                      icon: _isCalculatingRoute
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.alt_route_rounded),
                      label: Text(
                        _isCalculatingRoute
                            ? "Finding Route..."
                            : "Find Route",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ---------------- DRAGGABLE PANEL ----------------
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              if ((_sheetExtent - notification.extent).abs() > 0.005 && mounted) {
                setState(() {
                  _sheetExtent = notification.extent;
                });
              }
              return false;
            },
            child: DraggableScrollableSheet(
              initialChildSize: 0.12,
              minChildSize: 0.12,
              maxChildSize: 0.45,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22).withOpacity(0.96),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 22,
                        offset: const Offset(0, -8),
                      ),
                    ],
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
          ),

          // __________ SOS BUTTON __________
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            top: _sheetExtent > 0.17 ? 210 : 248,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _sheetExtent > 0.17 ? 0 : 1,
              child: IgnorePointer(
                ignoring: _sheetExtent > 0.17,
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xCCFF4B57),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFFD1D5)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x55FF4B57),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {},
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xCC2F6BFF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFBED0FF)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x552F6BFF),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _isPickingDestination
                              ? _cancelMapPickMode
                              : _enableMapPickMode,
                          child: Icon(
                            _isPickingDestination
                                ? Icons.close_rounded
                                : Icons.push_pin_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xCC65A2FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFD7E7FF)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x5565A2FF),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _goToMyLocation,
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: (_confirmedPinnedPosition != null ||
                                _selectedDestinationPosition != null ||
                                _destinationController.text.isNotEmpty)
                            ? const Color(0xCCFF6B6B)
                            : const Color(0xCC8E98A8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: (_confirmedPinnedPosition != null ||
                                  _selectedDestinationPosition != null ||
                                  _destinationController.text.isNotEmpty)
                              ? const Color(0xFFFFD0D0)
                              : const Color(0xFFD5DBE5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_confirmedPinnedPosition != null ||
                                    _selectedDestinationPosition != null ||
                                    _destinationController.text.isNotEmpty)
                                ? const Color(0x55FF6B6B)
                                : const Color(0x338E98A8),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: (_confirmedPinnedPosition != null ||
                                  _selectedDestinationPosition != null ||
                                  _destinationController.text.isNotEmpty)
                              ? _clearRoute
                              : null,
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: (_confirmedPinnedPosition != null ||
                                    _selectedDestinationPosition != null ||
                                    _destinationController.text.isNotEmpty)
                                ? Colors.white
                                : Colors.white.withOpacity(0.78),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
