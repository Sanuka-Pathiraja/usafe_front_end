import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/src/config/app_config.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

const String mapboxToken = mapboxPublicToken;

class _DangerZone {
  final Position? center;
  final double radius;
  final List<Position> polygon;

  const _DangerZone({
    required this.center,
    required this.radius,
    required this.polygon,
  });
}

class _SafeRoutePath {
  final List<Position> path;
  final double? distance;
  final double? duration;
  final String color;

  const _SafeRoutePath({
    required this.path,
    required this.distance,
    required this.duration,
    required this.color,
  });
}

class _SafeRoutePayload {
  final List<_DangerZone> redZones;
  final _SafeRoutePath originalRoute;
  final _SafeRoutePath? safeRoute;

  const _SafeRoutePayload({
    required this.redZones,
    required this.originalRoute,
    required this.safeRoute,
  });
}

class SafeRouteNavigationScreen extends StatefulWidget {
  const SafeRouteNavigationScreen({super.key});

  @override
  State<SafeRouteNavigationScreen> createState() =>
      _SafeRouteNavigationScreenState();
}

class _SafeRouteNavigationScreenState extends State<SafeRouteNavigationScreen> {
  // ── Map controllers ──────────────────────────────────────────────────────
  MapboxMap? _mapController;
  PolylineAnnotationManager? _polylineManager;
  PolylineAnnotationManager? _dangerZonePolylineManager;
  PointAnnotationManager? _pointAnnotationManager;
  CircleAnnotationManager? _userLocationManager;
  CircleAnnotationManager? _heatmapCircleManager;
  CircleAnnotation? _userLocationAnnotation;

  static const double _myLocationZoomOutLevel = 14.5;

  // ── Search ───────────────────────────────────────────────────────────────
  final TextEditingController _destinationController = TextEditingController();
  final Location _location = Location();

  Timer? _debounce;
  Timer? _zoneRefreshDebounce;
  Timer? _zonePulseTimer;
  List<Map<String, dynamic>> _destinationSuggestions = [];
  bool _isSearchingSuggestions = false;
  String _searchSessionToken = '';
  String? _lastZoneViewportKey;
  List<_DangerZone> _currentDangerZones = const <_DangerZone>[];
  bool _zonePulseExpanded = false;
  String? _selectedDestinationMapboxId;
  Position? _selectedDestinationPosition;

  // ── Route state ──────────────────────────────────────────────────────────
  LocationData? _currentPosition;
  String _distanceText = "Distance: --";
  String _durationText = "Estimated Time: --";
  bool _isCalculatingRoute = false;
  bool _hasActiveRoute = false;
  StreamSubscription<LocationData>? _locationSubscription;
  int _suggestionRequestId = 0;

  // ── Pin-pick state ───────────────────────────────────────────────────────
  bool _isPickingDestination = false;
  Position? _pendingPinnedPosition;
  Position? _confirmedPinnedPosition;
  Uint8List? _destinationMarkerBytes;

  // ── Sheet state ──────────────────────────────────────────────────────────
  double _sheetExtent = 0.12;

  // ── Computed ─────────────────────────────────────────────────────────────
  bool get _hasSelectedDestination =>
      _confirmedPinnedPosition != null ||
      _selectedDestinationPosition != null ||
      _destinationController.text.trim().isNotEmpty;

  bool get _showRouteDetails => _hasSelectedDestination && _hasActiveRoute;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _refreshSearchSessionToken();
    // FIX 1 ─ Set the Mapbox access token here, synchronously, before the
    // first frame renders the MapWidget.  This is the correct place when the
    // screen is pushed via Navigator (i.e. NOT set at app startup in main()).
    MapboxOptions.setAccessToken(mapboxToken);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _debounce?.cancel();
    _zoneRefreshDebounce?.cancel();
    _zonePulseTimer?.cancel();
    _destinationController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Map creation callback  ← FIX 2: map is built in build(), not initState()
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapController = map;

    _polylineManager = await map.annotations.createPolylineAnnotationManager();
    _dangerZonePolylineManager =
        await map.annotations.createPolylineAnnotationManager();
    _pointAnnotationManager =
        await map.annotations.createPointAnnotationManager();
    _userLocationManager =
        await map.annotations.createCircleAnnotationManager();
    _heatmapCircleManager =
        await map.annotations.createCircleAnnotationManager();

    await _startUserLocationTracking();
    final cameraState = await map.getCameraState();
    final initialCenter = _positionFromPoint(cameraState.center);
    await _loadDangerZones(
      viewportCenter: initialCenter,
      viewportZoom: cameraState.zoom.toDouble(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Location helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadDangerZones({
    Position? viewportCenter,
    double? viewportZoom,
  }) async {
    try {
      final token = await AuthService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token.trim().isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final queryParams = <String, String>{};
      if (viewportCenter != null) {
        queryParams['centerLat'] = viewportCenter.lat.toStringAsFixed(6);
        queryParams['centerLon'] = viewportCenter.lng.toStringAsFixed(6);
      }
      if (viewportZoom != null) {
        queryParams['zoom'] = viewportZoom.toStringAsFixed(2);
      }
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/safe-route')
            .replace(queryParameters: queryParams.isEmpty ? null : queryParams),
        headers: headers,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final root = _extractSafeRouteRoot(decoded);
          if (root != null) {
            final zones = _parseDangerZones(root['redZones']);
            if (zones.isNotEmpty) {
              await _renderDangerZones(zones);
              return;
            }
          }
        }
      }

      // Fallback: when /safe-route has no zone payload yet, use report feed
      // coordinates so danger overlays are still visible.
      final feedResponse = await http.get(
        Uri.parse('http://10.0.2.2:5000/report/feed')
            .replace(queryParameters: queryParams.isEmpty ? null : queryParams),
        headers: headers,
      );
      if (feedResponse.statusCode < 200 || feedResponse.statusCode >= 300) {
        return;
      }
      final feedDecoded = jsonDecode(feedResponse.body);
      final fallbackZones = _parseReportFeedAsDangerZones(feedDecoded);
      await _renderDangerZones(fallbackZones);
    } catch (e) {
      // Keep this silent in production-safe fallback mode.
    }
  }

  void _scheduleDangerZoneRefresh({
    required Position center,
    required double zoom,
  }) {
    final viewportKey =
        '${center.lat.toStringAsFixed(3)}|${center.lng.toStringAsFixed(3)}|${zoom.toStringAsFixed(1)}';
    if (viewportKey == _lastZoneViewportKey) return;

    _zoneRefreshDebounce?.cancel();
    _zoneRefreshDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      _lastZoneViewportKey = viewportKey;
      await _loadDangerZones(
        viewportCenter: center,
        viewportZoom: zoom,
      );
    });
  }

  List<_DangerZone> _parseReportFeedAsDangerZones(dynamic decoded) {
    List<dynamic> reports = <dynamic>[];
    if (decoded is List) {
      reports = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final items = decoded['reports'] ?? decoded['feed'] ?? decoded['data'];
      if (items is List) reports = items;
    }

    final zones = <_DangerZone>[];
    for (final item in reports) {
      if (item is! Map) continue;
      final report = Map<String, dynamic>.from(item as Map);
      final center = _parseLatLonPosition(
            report['locationCoordinates'] ??
                report['coordinates'] ??
                report['location'] ??
                report['center'],
          ) ??
          _parseLatLonPosition(
            report['location'] is Map
                ? (report['location'] as Map)['coordinates']
                : null,
          ) ??
          _parseLatLonPosition(
            report['location'] is Map
                ? (report['location'] as Map)['locationCoordinates']
                : null,
          );
      if (center == null) continue;
      zones.add(
        _DangerZone(
          center: center,
          radius: 50,
          polygon: const <Position>[],
        ),
      );
    }
    return _dedupeDangerZones(zones);
  }

  Map<String, dynamic>? _extractSafeRouteRoot(Map<String, dynamic> decoded) {
    if (decoded['originalRoute'] is Map || decoded['redZones'] is List) {
      return decoded;
    }
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<_SafeRoutePayload?> _fetchSafeRoutePayload() async {
    final token = await AuthService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token.trim().isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final response = await http.get(
      Uri.parse('http://10.0.2.2:5000/safe-route'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    final root = _extractSafeRouteRoot(decoded);
    if (root == null) return null;

    final originalRouteNode = root['originalRoute'];
    if (originalRouteNode is! Map) return null;
    final originalRoute = _parseSafeRoutePath(originalRouteNode);
    if (originalRoute == null || originalRoute.path.isEmpty) return null;

    _SafeRoutePath? safeRoute;
    final safeRouteNode = root['safeRoute'];
    if (safeRouteNode is Map) {
      safeRoute = _parseSafeRoutePath(safeRouteNode);
    }

    final redZonesNode = root['redZones'];
    final redZones = _parseDangerZones(redZonesNode);

    return _SafeRoutePayload(
      redZones: redZones,
      originalRoute: originalRoute,
      safeRoute: safeRoute,
    );
  }

  List<_DangerZone> _parseDangerZones(dynamic node) {
    if (node is! List) return const <_DangerZone>[];
    final zones = <_DangerZone>[];
    for (final item in node) {
      if (item is! Map) continue;
      final zone = Map<String, dynamic>.from(item as Map);
      final center = _parseLatLonPosition(zone['center']);
      final radius = _toDouble(zone['radius']) ?? 0.0;

      final polygon = <Position>[];
      final polygonNode = zone['polygon'];
      if (polygonNode is List) {
        for (final p in polygonNode) {
          final pos = _parseLatLonPosition(p);
          if (pos != null) polygon.add(pos);
        }
      }

      zones.add(
        _DangerZone(
          center: center,
          radius: radius,
          polygon: polygon,
        ),
      );
    }
    return _dedupeDangerZones(zones);
  }

  List<_DangerZone> _dedupeDangerZones(List<_DangerZone> zones) {
    final seen = <String>{};
    final deduped = <_DangerZone>[];

    for (final zone in zones) {
      final center = zone.center;
      if (center == null && zone.polygon.isEmpty) {
        continue;
      }

      final key = center != null
          ? 'c:${center.lat.toStringAsFixed(5)},${center.lng.toStringAsFixed(5)},r:${zone.radius.toStringAsFixed(1)}'
          : 'p:${zone.polygon.map((p) => '${p.lat.toStringAsFixed(5)},${p.lng.toStringAsFixed(5)}').join('|')}';

      if (seen.add(key)) {
        deduped.add(zone);
      }
    }

    return deduped;
  }

  _SafeRoutePath? _parseSafeRoutePath(dynamic node) {
    if (node is! Map) return null;
    final route = Map<String, dynamic>.from(node as Map);
    final pathNode = route['path'];
    if (pathNode is! List) return null;

    final path = <Position>[];
    for (final item in pathNode) {
      if (item is List && item.length >= 2) {
        final lon = _toDouble(item[0]);
        final lat = _toDouble(item[1]);
        if (lat != null && lon != null) {
          path.add(Position(lon, lat));
        }
        continue;
      }
      final p = _parseLatLonPosition(item);
      if (p != null) {
        path.add(p);
      }
    }
    if (path.isEmpty) return null;

    return _SafeRoutePath(
      path: path,
      distance: _toDouble(route['distance']),
      duration: _toDouble(route['duration']),
      color: (route['color'] ?? '').toString().trim().toLowerCase(),
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double _distanceMeters(Position a, Position b) {
    const earthRadiusMeters = 6371000.0;
    final aLat = a.lat.toDouble();
    final aLng = a.lng.toDouble();
    final bLat = b.lat.toDouble();
    final bLng = b.lng.toDouble();
    final dLat = _degToRad(bLat - aLat);
    final dLon = _degToRad(bLng - aLng);
    final lat1 = _degToRad(aLat);
    final lat2 = _degToRad(bLat);

    final haversine = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(haversine), sqrt(1 - haversine));
    return earthRadiusMeters * c;
  }

  double _degToRad(double degrees) => degrees * (pi / 180.0);

  Position? _parseLatLonPosition(dynamic node) {
    if (node is List && node.length >= 2) {
      final lon = _toDouble(node[0]);
      final lat = _toDouble(node[1]);
      if (lat != null && lon != null) {
        return Position(lon, lat);
      }
      return null;
    }

    if (node is! Map) return null;
    final map = Map<String, dynamic>.from(node as Map);

    final lat = _toDouble(map['lat'] ?? map['latitude']);
    final lon = _toDouble(
      map['lon'] ?? map['lng'] ?? map['long'] ?? map['longitude'],
    );
    if (lat != null && lon != null) {
      return Position(lon, lat);
    }

    final nested = map['coordinates'] ?? map['locationCoordinates'];
    if (nested is List && nested.length >= 2) {
      final nestedLon = _toDouble(nested[0]);
      final nestedLat = _toDouble(nested[1]);
      if (nestedLat != null && nestedLon != null) {
        return Position(nestedLon, nestedLat);
      }
    } else if (nested is Map) {
      final nestedPos = _parseLatLonPosition(nested);
      if (nestedPos != null) return nestedPos;
    }

    return null;
  }

  Future<void> _renderDangerZones(List<_DangerZone> zones) async {
    _currentDangerZones = zones;
    _startDangerZonePulse();
    await _drawDangerZonesFrame();
  }

  void _startDangerZonePulse() {
    _zonePulseTimer?.cancel();
    if (_currentDangerZones.isEmpty) return;

    _zonePulseTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) async {
        if (!mounted) return;
        _zonePulseExpanded = !_zonePulseExpanded;
        await _drawDangerZonesFrame();
      },
    );
  }

  Future<void> _drawDangerZonesFrame() async {
    final circleManager = _heatmapCircleManager;
    final polygonManager = _dangerZonePolylineManager;
    if (circleManager == null || polygonManager == null) return;

    await circleManager.deleteAll();
    await polygonManager.deleteAll();
    if (_currentDangerZones.isEmpty) return;

    final pulseScale = _zonePulseExpanded ? 1.16 : 1.0;

    for (final zone in _currentDangerZones) {
      final center = zone.center;
      if (center != null) {
        final circleRadius = ((zone.radius / 4) * pulseScale).clamp(10.0, 40.0);
        final innerRadius = (circleRadius * 0.48).clamp(5.0, 16.0);

        // Outer danger aura.
        await circleManager.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: center),
            circleRadius: circleRadius,
            circleColor: const Color(0x55FF3B30).value,
            circleStrokeColor: const Color(0xCCFF3B30).value,
            circleStrokeWidth: 2.0,
          ),
        );

        // Inner hotspot to increase visual contrast of the danger center.
        await circleManager.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: center),
            circleRadius: innerRadius,
            circleColor: const Color(0xCCFF3B30).value,
            circleStrokeColor: const Color(0xFFFFE3E0).value,
            circleStrokeWidth: 1.0,
          ),
        );
      }

      if (zone.polygon.length >= 3) {
        final closed = <Position>[...zone.polygon, zone.polygon.first];
        await polygonManager.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: closed),
            lineColor: const Color(0xAAFF3B30).value,
            lineWidth: 3.0,
          ),
        );
      }
    }
  }

  void _refreshSearchSessionToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256)).map((v) {
      return v.toRadixString(16).padLeft(2, '0');
    }).join();
    _searchSessionToken = '${bytes.substring(0, 8)}-${bytes.substring(8, 12)}-'
        '${bytes.substring(12, 16)}-${bytes.substring(16, 20)}-'
        '${bytes.substring(20, 32)}';
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
          'proximity=${_currentPosition!.longitude},${_currentPosition!.latitude}');
    }
    return params.join('&');
  }

  Position _positionFromLocation(LocationData loc) =>
      Position(loc.longitude!, loc.latitude!);

  Position _positionFromPoint(Point point) => point.coordinates;

  CircleAnnotationOptions _buildUserLocationMarker(Position pos) =>
      CircleAnnotationOptions(
        geometry: Point(coordinates: pos),
        circleColor: Colors.blue.value,
        circleRadius: 8.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.value,
        circleSortKey: 100,
      );

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
          bearing: 0),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _syncUserLocationMarker({
    required LocationData location,
    bool moveCamera = false,
  }) async {
    if (_userLocationManager == null ||
        location.latitude == null ||
        location.longitude == null) return;

    final position = _positionFromLocation(location);

    if (_userLocationAnnotation == null) {
      _userLocationAnnotation = await _userLocationManager!
          .create(_buildUserLocationMarker(position));
    } else {
      _userLocationAnnotation!.geometry = Point(coordinates: position);
      await _userLocationManager!.update(_userLocationAnnotation!);
    }

    if (moveCamera) await _moveCameraToPosition(position);
  }

  Future<void> _startUserLocationTracking() async {
    final hasAccess = await _ensureLocationAccess();
    if (!hasAccess) return;

    await _location.changeSettings(
        accuracy: LocationAccuracy.high, interval: 2000, distanceFilter: 5);

    final initialLocation = await _location.getLocation();
    _currentPosition = initialLocation;
    await _syncUserLocationMarker(location: initialLocation, moveCamera: true);

    _locationSubscription?.cancel();
    _locationSubscription =
        _location.onLocationChanged.listen((location) async {
      if (!mounted || location.latitude == null || location.longitude == null)
        return;
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
        Position(_currentPosition!.longitude!, _currentPosition!.latitude!));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pin-pick helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _pinnedLocationLabel(Position position) =>
      'Pinned (${position.lat.toStringAsFixed(5)}, '
      '${position.lng.toStringAsFixed(5)})';

  Future<Uint8List> _loadDestinationMarkerBytes() async {
    if (_destinationMarkerBytes != null) return _destinationMarkerBytes!;
    final bytes = await rootBundle.load('assets/red-pin bg r.png');
    _destinationMarkerBytes = bytes.buffer.asUint8List();
    return _destinationMarkerBytes!;
  }

  Future<void> _showDestinationPin(Position position) async {
    final pm = _pointAnnotationManager;
    if (pm == null) return;
    await pm.deleteAll();
    final markerBytes = await _loadDestinationMarkerBytes();
    await pm.create(PointAnnotationOptions(
      geometry: Point(coordinates: position),
      image: markerBytes,
      iconSize: 0.2,
      iconAnchor: IconAnchor.BOTTOM,
    ));
  }

  Future<void> _enableMapPickMode() async {
    FocusScope.of(context).unfocus();
    Position? initialPin =
        _confirmedPinnedPosition ?? _selectedDestinationPosition;
    if (initialPin == null && _currentPosition != null) {
      initialPin =
          Position(_currentPosition!.longitude!, _currentPosition!.latitude!);
    }
    if (initialPin != null) {
      _pendingPinnedPosition = initialPin;
      await _moveCameraToPosition(initialPin);
    } else if (_mapController != null) {
      final cameraState = await _mapController!.getCameraState();
      _pendingPinnedPosition = _positionFromPoint(cameraState.center);
    }
    if (!mounted) return;
    setState(() => _isPickingDestination = true);
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
    final confirmed = position;
    await _showDestinationPin(confirmed);
    if (!mounted) return;
    setState(() {
      _confirmedPinnedPosition = confirmed;
      _selectedDestinationPosition = confirmed;
      _selectedDestinationMapboxId = null;
      _destinationSuggestions = [];
      _destinationController.text = _pinnedLocationLabel(confirmed);
      _hasActiveRoute = false;
      _isPickingDestination = false;
      _pendingPinnedPosition = null;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Route helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleFindRoute() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isCalculatingRoute = true;
      _hasActiveRoute = false;
    });
    try {
      if (_currentPosition == null) await _getRealLocation();
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
      final start =
          Position(_currentPosition!.longitude!, _currentPosition!.latitude!);
      final payload = await _fetchSafeRoutePayload();
      if (payload != null) {
        final safe = payload.safeRoute;
        final preferredRoute = (safe != null && safe.path.isNotEmpty)
            ? safe
            : payload.originalRoute;
        final backendEnd = preferredRoute.path.isNotEmpty
            ? preferredRoute.path.last
            : destination;
        final mismatchMeters = _distanceMeters(backendEnd, destination);
        const maxAllowedMismatchMeters = 350.0;
        if (mismatchMeters > maxAllowedMismatchMeters) {
          _showSnackBar(
            "Showing standard route for selected destination.",
          );
          await drawRoute(start, destination);
          return;
        }
        await _renderDangerZones(payload.redZones);
        await _drawRoutesFromSafeRoutePayload(destination, payload);
      } else {
        await drawRoute(start, destination);
      }
    } catch (e) {
      _showSnackBar("Route error: $e");
    } finally {
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }

  Future<void> _drawRoutesFromSafeRoutePayload(
    Position end,
    _SafeRoutePayload payload,
  ) async {
    if (_mapController == null ||
        _polylineManager == null ||
        _pointAnnotationManager == null) return;

    await _polylineManager!.deleteAll();
    await _pointAnnotationManager!.deleteAll();

    await _polylineManager!.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: payload.originalRoute.path),
        lineColor: _routeColorValue(payload.originalRoute.color),
        lineWidth: 4.0,
      ),
    );

    final safe = payload.safeRoute;
    if (safe != null && safe.path.isNotEmpty) {
      await _polylineManager!.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: safe.path),
          lineColor: _routeColorValue(safe.color),
          lineWidth: 6.0,
        ),
      );
    }

    final preferredRoute =
        (safe != null && safe.path.isNotEmpty) ? safe : payload.originalRoute;
    final markerTarget =
        preferredRoute.path.isNotEmpty ? preferredRoute.path.last : end;

    final markerBytes = await _loadDestinationMarkerBytes();
    await _pointAnnotationManager!.create(PointAnnotationOptions(
      geometry: Point(coordinates: markerTarget),
      image: markerBytes,
      iconSize: 0.2,
      iconAnchor: IconAnchor.BOTTOM,
    ));

    final distM = preferredRoute.distance ?? 0.0;
    final durS = preferredRoute.duration ?? 0.0;

    if (mounted) {
      setState(() {
        _confirmedPinnedPosition = markerTarget;
        _selectedDestinationPosition = markerTarget;
        _distanceText = distM > 0
            ? "Distance: ${(distM / 1000).toStringAsFixed(1)} km"
            : "Distance: --";
        _durationText = durS > 0
            ? "Estimated Time: ${(durS / 60).toStringAsFixed(0)} mins"
            : "Estimated Time: --";
        _hasActiveRoute = true;
      });
    }

    await _mapController!.flyTo(
      CameraOptions(center: Point(coordinates: markerTarget), zoom: 12.5),
      MapAnimationOptions(duration: 1200),
    );
  }

  int _routeColorValue(String colorName) {
    final color = colorName.trim().toLowerCase();
    switch (color) {
      case 'green':
        return const Color(0xFF1DB954).value;
      case 'red':
        return const Color(0xFFEF4444).value;
      case 'yellow':
        return const Color(0xFFFACC15).value;
      case 'orange':
        return const Color(0xFFF97316).value;
      case 'blue':
        return const Color(0xFF2962FF).value;
      case 'grey':
      case 'gray':
        return const Color(0xFF7E8A9A).value;
      default:
        return const Color(0xFF2962FF).value;
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
        _hasActiveRoute = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isSearchingSuggestions = true);

    try {
      var parsed = <Map<String, dynamic>>[];
      final geocodingSuggestion =
          await _geocodingFallbackSuggestion(trimmedQuery);
      if (geocodingSuggestion != null) {
        parsed = [geocodingSuggestion];
      } else {
        final url = Uri.parse(
            "https://api.mapbox.com/search/searchbox/v1/suggest"
            "?q=${Uri.encodeComponent(trimmedQuery)}&${_buildSearchBoxCommonParams()}");
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final suggestions = data['suggestions'];
          parsed = suggestions is List
              ? suggestions
                  .whereType<Map>()
                  .map((f) => Map<String, dynamic>.from(f))
                  .toList()
              : [];
        }
      }
      if (!mounted || requestId != _suggestionRequestId) return;
      setState(() => _destinationSuggestions = parsed);
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
        "https://api.mapbox.com/search/searchbox/v1/retrieve/$mapboxId"
        "?access_token=$mapboxToken&session_token=$_searchSessionToken&language=en");
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
          'proximity=${_currentPosition!.longitude},${_currentPosition!.latitude}');
    }
    final url = Uri.parse("https://api.mapbox.com/search/searchbox/v1/forward"
        "?q=${Uri.encodeComponent(place.trim())}&${params.join('&')}");
    final response = await http.get(url);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final features = data['features'];
    if (features is! List || features.isEmpty) return null;
    final featureMap = features.first is Map<String, dynamic>
        ? features.first as Map<String, dynamic>
        : Map<String, dynamic>.from(features.first as Map);
    final coords =
        (featureMap['geometry'] as Map<String, dynamic>?)?['coordinates'];
    if (coords is List && coords.length >= 2) {
      return Position(
          (coords[0] as num).toDouble(), (coords[1] as num).toDouble());
    }
    return null;
  }

  Future<Position?> _geocodingFallbackDestination(String place) async {
    try {
      final results = await geocoding
          .locationFromAddress(place.trim())
          .timeout(const Duration(seconds: 8));
      if (results.isEmpty) return null;
      return Position(results.first.longitude, results.first.latitude);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _geocodingFallbackSuggestion(
      String place) async {
    try {
      final results = await geocoding
          .locationFromAddress(place.trim())
          .timeout(const Duration(seconds: 8));
      if (results.isEmpty) return null;
      return <String, dynamic>{
        'name': place.trim(),
        'full_address': place.trim(),
        'feature_type': 'place',
        'source': 'geocoding_fallback',
        'fallback_lat': results.first.latitude,
        'fallback_lng': results.first.longitude,
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
          "?q=${Uri.encodeComponent(place.trim())}&${_buildSearchBoxCommonParams()}");
      final suggestResponse = await http.get(suggestUrl);
      if (suggestResponse.statusCode != 200) {
        return _resolveDestinationFallback(place);
      }
      final suggestData =
          jsonDecode(suggestResponse.body) as Map<String, dynamic>;
      final suggestions = suggestData['suggestions'];
      if (suggestions is! List || suggestions.isEmpty) {
        return _resolveDestinationFallback(place);
      }
      mapboxId = suggestions.first['mapbox_id']?.toString();
    }
    if (mapboxId == null || mapboxId.isEmpty) {
      return _resolveDestinationFallback(place);
    }
    final feature = await _retrieveSuggestion(mapboxId);
    if (feature == null) return _resolveDestinationFallback(place);
    final coords =
        (feature['geometry'] as Map<String, dynamic>?)?['coordinates'];
    if (coords is List && coords.length >= 2) {
      return Position(
          (coords[0] as num).toDouble(), (coords[1] as num).toDouble());
    }
    return _resolveDestinationFallback(place);
  }

  Future<Position?> _resolveDestinationFallback(String place) async {
    return await _forwardSearchDestination(place) ??
        await _geocodingFallbackDestination(place);
  }

  Future<void> drawRoute(Position start, Position end) async {
    if (_mapController == null ||
        _polylineManager == null ||
        _pointAnnotationManager == null) return;

    final url = Uri.parse("https://api.mapbox.com/directions/v5/mapbox/driving/"
        "${start.lng},${start.lat};${end.lng},${end.lat}"
        "?geometries=geojson&overview=full&alternatives=false"
        "&access_token=$mapboxToken");
    final response = await http.get(url);
    if (response.statusCode != 200) {
      _showSnackBar("Directions API failed: ${response.statusCode}");
      return;
    }

    final data = jsonDecode(response.body);
    final routeCoords = (data['routes'][0]['geometry']['coordinates']
            as List<dynamic>)
        .map(
            (c) => Position((c[0] as num).toDouble(), (c[1] as num).toDouble()))
        .toList();

    await _polylineManager!.deleteAll();
    await _pointAnnotationManager!.deleteAll();

    await _polylineManager!.create(PolylineAnnotationOptions(
      geometry: LineString(coordinates: routeCoords),
      lineColor: const Color(0xFF2962FF).value,
      lineWidth: 5.0,
    ));

    final markerBytes = await _loadDestinationMarkerBytes();
    await _pointAnnotationManager!.create(PointAnnotationOptions(
      geometry: Point(coordinates: end),
      image: markerBytes,
      iconSize: 0.2,
      iconAnchor: IconAnchor.BOTTOM,
    ));

    final distM = (data['routes'][0]['distance'] as num?)?.toDouble() ?? 0.0;
    final durS = (data['routes'][0]['duration'] as num?)?.toDouble() ?? 0.0;

    if (mounted) {
      setState(() {
        _confirmedPinnedPosition = end;
        _selectedDestinationPosition = end;
        _distanceText = "Distance: ${(distM / 1000).toStringAsFixed(1)} km";
        _durationText =
            "Estimated Time: ${(durS / 60).toStringAsFixed(0)} mins";
        _hasActiveRoute = true;
      });
    }

    await _mapController!.flyTo(
      CameraOptions(center: Point(coordinates: end), zoom: 12.5),
      MapAnimationOptions(duration: 1200),
    );
  }

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
        _hasActiveRoute = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Suggestion UI helpers
  // ─────────────────────────────────────────────────────────────────────────

  IconData _getIconForType(List<dynamic>? types) {
    if (types == null || types.isEmpty) return Icons.location_on;
    if (types.contains('poi')) return Icons.place;
    if (types.contains('address')) return Icons.home_outlined;
    if (types.contains('locality')) return Icons.location_city;
    if (types.contains('place')) return Icons.map_outlined;
    return Icons.location_on;
  }

  List<dynamic>? _suggestionTypes(Map<String, dynamic> s) {
    final featureType = s['feature_type']?.toString();
    final poiCategory = s['poi_category'];
    if (poiCategory is List && poiCategory.isNotEmpty) {
      return ['poi', ...poiCategory];
    }
    if (featureType == null || featureType.isEmpty) return null;
    return [featureType];
  }

  String _suggestionLabel(Map<String, dynamic> s) {
    final name = s['name']?.toString().trim() ?? '';
    final address = s['full_address']?.toString().trim() ?? '';
    if (address.isEmpty) return name;
    if (name.isEmpty) return address;
    if (address.startsWith(name)) return address;
    return '$name, $address';
  }

  String _formatPlaceType(List<dynamic>? types) {
    if (types == null || types.isEmpty) return 'Location';
    return types
        .whereType<String>()
        .map((t) => t.replaceAll('_', ' '))
        .map((t) => t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}')
        .join(', ');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reusable FAB tile
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFab({
    required Color color,
    required Color borderColor,
    required Color shadowColor,
    required IconData icon,
    required VoidCallback? onTap,
    double iconOpacity = 1.0,
    double iconSize = 26,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
              color: shadowColor, blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Icon(icon,
              color: Colors.white.withOpacity(iconOpacity), size: iconSize),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Top padding = status bar + AppBar height
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 12;

    return Scaffold(
      backgroundColor: AppColors.background,
      // extendBodyBehindAppBar lets the map fill the whole screen
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.92),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Safe Route Navigation",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ── FIX 2: MapWidget lives directly in build(), NOT in initState ──
          // This ensures the platform view always attaches to the live tree
          // when the screen is pushed via Navigator.push.
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey("mapbox_safe_route"),
              styleUri: MapboxStyles.STANDARD,
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(80.7718, 7.8731)),
                zoom: 7,
              ),
              onTapListener: (_) async {
                if (!mounted) return;
                FocusScope.of(context).unfocus();
              },
              onCameraChangeListener: (event) {
                final cameraCenter =
                    _positionFromPoint(event.cameraState.center);
                _scheduleDangerZoneRefresh(
                  center: Position(cameraCenter.lng, cameraCenter.lat),
                  zoom: event.cameraState.zoom.toDouble(),
                );
                if (!_isPickingDestination) return;
                _pendingPinnedPosition =
                    _positionFromPoint(event.cameraState.center);
              },
              onMapIdleListener: (_) {
                if (!mounted || !_isPickingDestination) return;
                setState(() {});
              },
              onMapCreated: _onMapCreated,
            ),
          ),

          // ── Search panel ─────────────────────────────────────────────────
          Positioned(
            top: topPad,
            left: 16,
            right: 16,
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
                  // ── Search field ────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                            setState(() {
                              _selectedDestinationMapboxId = null;
                              _selectedDestinationPosition = null;
                              _confirmedPinnedPosition = null;
                              _hasActiveRoute = false;
                            });
                            _debounce?.cancel();
                            _debounce =
                                Timer(const Duration(milliseconds: 500), () {
                              fetchSuggestions(value);
                            });
                          },
                          decoration: InputDecoration(
                            hintText: "Enter destination",
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.62)),
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
                                          color: Colors.white.withOpacity(0.72),
                                          size: 19,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _clearRoute,
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: Colors.white.withOpacity(0.62),
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                        ),

                        // Loading spinner
                        if (_isSearchingSuggestions)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),

                        // Suggestion list
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
                              separatorBuilder: (_, __) =>
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
                                  title: Text(
                                    _suggestionLabel(suggestion),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _formatPlaceType(types),
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]),
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
                                        fallbackLat is num && fallbackLng is num
                                            ? Position(fallbackLng.toDouble(),
                                                fallbackLat.toDouble())
                                            : null;
                                    _destinationController.text =
                                        _suggestionLabel(suggestion);
                                    setState(() {
                                      _destinationSuggestions = [];
                                      _hasActiveRoute = false;
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

                  // Pinned location label
                  if (_confirmedPinnedPosition != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        children: [
                          Icon(Icons.place_rounded,
                              color: Colors.white.withOpacity(0.72), size: 14),
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

          // ── Pin-mode crosshair ────────────────────────────────────────
          if (_isPickingDestination)
            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: const Icon(Icons.location_on_rounded,
                      size: 52, color: Colors.red),
                ),
              ),
            ),

          // ── Pin-mode confirm card ─────────────────────────────────────
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
                          child: const Icon(Icons.push_pin_rounded,
                              color: Color(0xFF2F6BFF), size: 18),
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
                          color: Color(0xFF6B7280), fontSize: 12.5),
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
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Pin This Location',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Find Route button ─────────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 16,
            right: 16,
            bottom: _sheetExtent > 0.17 ? 88 : 112,
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
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _isCalculatingRoute ? null : _handleFindRoute,
                      icon: _isCalculatingRoute
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.alt_route_rounded),
                      label: Text(
                        _isCalculatingRoute ? "Finding Route..." : "Find Route",
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Draggable bottom sheet ────────────────────────────────────
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              if ((_sheetExtent - notification.extent).abs() > 0.005 &&
                  mounted) {
                setState(() => _sheetExtent = notification.extent);
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
                    color: AppColors.background.withOpacity(0.96),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: AppColors.glassBorder),
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
                      if (_showRouteDetails) ...[
                        const Text("Route Details",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            )),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.18)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_distanceText,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text(_durationText,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Start Navigation",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ] else ...[
                        Text(
                          "Select a destination and find a route to see navigation details.",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary.withOpacity(0.92),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Right-side FABs ───────────────────────────────────────────
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
                    // Pin / cancel
                    _buildFab(
                      color: const Color(0xCC2F6BFF),
                      borderColor: const Color(0xFFBED0FF),
                      shadowColor: const Color(0x552F6BFF),
                      icon: _isPickingDestination
                          ? Icons.close_rounded
                          : Icons.push_pin_rounded,
                      onTap: _isPickingDestination
                          ? _cancelMapPickMode
                          : _enableMapPickMode,
                      iconSize: 24,
                    ),
                    const SizedBox(height: 10),
                    // My location
                    _buildFab(
                      color: const Color(0xCC65A2FF),
                      borderColor: const Color(0xFFD7E7FF),
                      shadowColor: const Color(0x5565A2FF),
                      icon: Icons.my_location_rounded,
                      onTap: _goToMyLocation,
                      iconSize: 26,
                    ),
                    const SizedBox(height: 10),
                    // Clear
                    _buildFab(
                      color: _hasSelectedDestination
                          ? const Color(0xCCFF6B6B)
                          : const Color(0xCC8E98A8),
                      borderColor: _hasSelectedDestination
                          ? const Color(0xFFFFD0D0)
                          : const Color(0xFFD5DBE5),
                      shadowColor: _hasSelectedDestination
                          ? const Color(0x55FF6B6B)
                          : const Color(0x338E98A8),
                      icon: Icons.delete_outline_rounded,
                      onTap: _hasSelectedDestination ? _clearRoute : null,
                      iconOpacity: _hasSelectedDestination ? 1.0 : 0.78,
                      iconSize: 24,
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
