import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:location/location.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/src/config/app_config.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;

const String mapboxToken = mapboxPublicToken;

class _DangerZone {
  final Position? center;
  final double radius;
  final List<Position> polygon;
  final String threatLevel; // 'red' | 'orange' | 'yellow'
  final int? reportId;
  final List<String> issueTypes;
  final String? description;
  final String? reporter;
  final String? reportedAt;

  const _DangerZone({
    required this.center,
    required this.radius,
    required this.polygon,
    this.threatLevel = 'red',
    this.reportId,
    this.issueTypes = const [],
    this.description,
    this.reporter,
    this.reportedAt,
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

class _SafeRouteResponse {
  final bool destinationDangerous;
  final String? warningMessage;
  final _DangerZone? destinationZone;
  final List<_DangerZone> allZones;
  final _SafeRoutePayload? payload;

  const _SafeRouteResponse({
    required this.destinationDangerous,
    this.warningMessage,
    this.destinationZone,
    required this.allZones,
    this.payload,
  });
}

class SafeRouteNavigationScreen extends StatefulWidget {
  const SafeRouteNavigationScreen({super.key});

  @override
  State<SafeRouteNavigationScreen> createState() =>
      _SafeRouteNavigationScreenState();
}

class _SafeRouteNavigationScreenState extends State<SafeRouteNavigationScreen>
    with TickerProviderStateMixin {
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
  late final AnimationController _rippleController;
  final _zoneScreenDataNotifier = ValueNotifier<List<_ZoneScreenData>>(const []);
  Size _mapSize = Size.zero;
  List<Map<String, dynamic>> _destinationSuggestions = [];
  bool _isSearchingSuggestions = false;
  String _searchSessionToken = '';
  List<_DangerZone> _currentDangerZones = const <_DangerZone>[];
  final Map<String, _DangerZone> _annotationZoneMap = {};
  _DangerZone? _selectedZone;
  String? _destWarningMessage;
  bool _legendCollapsed = false;
  String? _selectedDestinationMapboxId;
  Position? _selectedDestinationPosition;

  // ── Route state ──────────────────────────────────────────────────────────
  LocationData? _currentPosition;
  String _distanceText = "Distance: --";
  String _durationText = "Estimated Time: --";
  bool _isCalculatingRoute = false;
  bool _hasActiveRoute = false;
  String _routeSourceLabel = 'None';
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
    MapboxOptions.setAccessToken(mapboxToken);
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _debounce?.cancel();
    _rippleController.dispose();
    _zoneScreenDataNotifier.dispose();
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

    _heatmapCircleManager!.tapEvents(
      onTap: (annotation) {
        final zone = _annotationZoneMap[annotation.id];
        if (zone != null && mounted) setState(() => _selectedZone = zone);
      },
    );

    await _startUserLocationTracking();
    await _loadAllDangerZones();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Location helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadAllDangerZones() async {
    try {
      final token = await AuthService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token.trim().isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/danger-zones'),
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body);
      List<dynamic> zoneList = const [];
      if (decoded is Map<String, dynamic>) {
        final v = decoded['zones'] ?? decoded['redZones'];
        if (v is List) zoneList = v;
      } else if (decoded is List) {
        zoneList = decoded;
      }
      final zones = _parseDangerZones(zoneList);
      if (zones.isNotEmpty) await _renderDangerZones(zones);
    } catch (_) {}
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

  Future<_SafeRouteResponse?> _fetchSafeRoute(
      Position start, Position end) async {
    try {
      final token = await AuthService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token.trim().isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/safe-route').replace(
          queryParameters: {
            'startLat': (_toDouble(start.lat) ?? 0).toString(),
            'startLon': (_toDouble(start.lng) ?? 0).toString(),
            'endLat': (_toDouble(end.lat) ?? 0).toString(),
            'endLon': (_toDouble(end.lng) ?? 0).toString(),
          },
        ),
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final allZones = _parseDangerZones(
          decoded['redZones'] is List ? decoded['redZones'] as List : const []);

      if (decoded['destinationDangerous'] == true) {
        return _SafeRouteResponse(
          destinationDangerous: true,
          warningMessage: decoded['message'] as String?,
          destinationZone: _parseSingleZone(decoded['destinationZone']),
          allZones: allZones,
        );
      }

      final root = _extractSafeRouteRoot(decoded);
      if (root == null) return null;
      final originalRouteNode = root['originalRoute'];
      if (originalRouteNode is! Map) return null;
      final originalRoute = _parseSafeRoutePath(originalRouteNode);
      if (originalRoute == null || originalRoute.path.isEmpty) return null;

      _SafeRoutePath? safeRoute;
      final safeRouteNode = root['safeRoute'];
      if (safeRouteNode is Map) safeRoute = _parseSafeRoutePath(safeRouteNode);

      return _SafeRouteResponse(
        destinationDangerous: false,
        allZones: allZones,
        payload: _SafeRoutePayload(
          redZones: allZones,
          originalRoute: originalRoute,
          safeRoute: safeRoute,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  List<_DangerZone> _parseDangerZones(dynamic node) {
    if (node is! List) return const <_DangerZone>[];
    final zones = <_DangerZone>[];
    for (final item in node) {
      if (item is! Map) continue;
      final zone = Map<String, dynamic>.from(item);
      final center = _parseLatLonPosition(zone['center']);
      final radius = _toDouble(zone['radius']) ?? 0.0;
      final threatLevel = zone['threatLevel'] as String? ?? 'red';
      final reportId = zone['reportId'] is int ? zone['reportId'] as int : null;
      final issueTypes = (zone['issueTypes'] is List)
          ? List<String>.from(
              (zone['issueTypes'] as List).map((e) => e.toString()))
          : const <String>[];
      final description = zone['description'] as String?;
      final reporter = zone['reporter'] as String?;
      final reportedAt = zone['reportedAt'] as String?;

      final polygon = <Position>[];
      final polygonNode = zone['polygon'];
      if (polygonNode is List) {
        for (final p in polygonNode) {
          final pos = _parseLatLonPosition(p);
          if (pos != null) polygon.add(pos);
        }
      }

      zones.add(_DangerZone(
        center: center,
        radius: radius,
        polygon: polygon,
        threatLevel: threatLevel,
        reportId: reportId,
        issueTypes: issueTypes,
        description: description,
        reporter: reporter,
        reportedAt: reportedAt,
      ));
    }
    return _dedupeDangerZones(zones);
  }

  _DangerZone? _parseSingleZone(dynamic node) {
    if (node is! Map) return null;
    final zone = Map<String, dynamic>.from(node);
    final center = _parseLatLonPosition(zone['center']);
    if (center == null) return null;
    final polygon = <Position>[];
    final polygonNode = zone['polygon'];
    if (polygonNode is List) {
      for (final p in polygonNode) {
        final pos = _parseLatLonPosition(p);
        if (pos != null) polygon.add(pos);
      }
    }
    return _DangerZone(
      center: center,
      radius: _toDouble(zone['radius']) ?? 100.0,
      polygon: polygon,
      threatLevel: zone['threatLevel'] as String? ?? 'red',
      reportId: zone['reportId'] is int ? zone['reportId'] as int : null,
      issueTypes: (zone['issueTypes'] is List)
          ? List<String>.from(
              (zone['issueTypes'] as List).map((e) => e.toString()))
          : const [],
      description: zone['description'] as String?,
      reporter: zone['reporter'] as String?,
      reportedAt: zone['reportedAt'] as String?,
    );
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
    final route = Map<String, dynamic>.from(node);
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

  List<Position> _dangerZonePointsForCameraFit() {
    final points = <Position>[];
    for (final zone in _currentDangerZones) {
      if (zone.center != null) {
        points.add(zone.center!);
      }
      if (zone.polygon.isNotEmpty) {
        points.addAll(zone.polygon);
      }
    }
    return points;
  }

  Future<void> _fitCameraToRouteAndZones(
    List<Position> routePoints, {
    Position? fallbackCenter,
  }) async {
    if (_mapController == null) return;

    final points = <Position>[
      ...routePoints,
      ..._dangerZonePointsForCameraFit(),
    ];
    if (points.isEmpty) {
      if (fallbackCenter != null) {
        await _mapController!.flyTo(
          CameraOptions(center: Point(coordinates: fallbackCenter), zoom: 12.5),
          MapAnimationOptions(duration: 900),
        );
      }
      return;
    }

    var minLat = points.first.lat.toDouble();
    var maxLat = points.first.lat.toDouble();
    var minLng = points.first.lng.toDouble();
    var maxLng = points.first.lng.toDouble();

    for (final p in points.skip(1)) {
      final lat = p.lat.toDouble();
      final lng = p.lng.toDouble();
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final center = Position((minLng + maxLng) / 2, (minLat + maxLat) / 2);
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final span = (max(latSpan, lngSpan) * 1.25).clamp(0.0005, 180.0);

    await _mapController!.flyTo(
      CameraOptions(
        center: Point(coordinates: center),
        zoom: _zoomFromSpan(span),
      ),
      MapAnimationOptions(duration: 1100),
    );
  }

  double _zoomFromSpan(double span) {
    if (span <= 0.002) return 16.5;
    if (span <= 0.005) return 15.5;
    if (span <= 0.01) return 14.7;
    if (span <= 0.02) return 13.9;
    if (span <= 0.04) return 13.0;
    if (span <= 0.08) return 12.0;
    if (span <= 0.16) return 11.0;
    if (span <= 0.32) return 10.0;
    if (span <= 0.64) return 9.0;
    return 8.0;
  }

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
    final map = Map<String, dynamic>.from(node);

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

  // Key representing what is currently drawn — avoids blink on identical reload.
  String _drawnZonesKey = '';

  static String _zonesKey(List<_DangerZone> zones) {
    if (zones.isEmpty) return '';
    return zones.map((z) {
      final c = z.center;
      return c != null
          ? 'c:${c.lat.toStringAsFixed(5)},${c.lng.toStringAsFixed(5)},r:${z.radius.toStringAsFixed(1)},t:${z.threatLevel}'
          : 'p:${z.polygon.length},t:${z.threatLevel}';
    }).join('|');
  }

  ({Color fill, Color stroke, Color ripple}) _threatColors(String level) {
    switch (level) {
      case 'orange':
        return (
          fill: const Color(0x33FF9500),
          stroke: const Color(0xCCFF9500),
          ripple: const Color(0xFFFF9500),
        );
      case 'yellow':
        return (
          fill: const Color(0x33FFCC00),
          stroke: const Color(0xCCFFCC00),
          ripple: const Color(0xFFFFCC00),
        );
      default: // 'red'
        return (
          fill: const Color(0x33FF3B30),
          stroke: const Color(0xCCFF3B30),
          ripple: const Color(0xFFFF3B30),
        );
    }
  }

  Future<void> _renderDangerZones(List<_DangerZone> zones) async {
    final key = _zonesKey(zones);
    final zonesChanged = key != _drawnZonesKey;
    _currentDangerZones = zones;
    if (zonesChanged) {
      _drawnZonesKey = key;
      await _drawDangerZonesStatic();
    }
    await _updateZoneScreenData();
  }

  /// Draws static (non-animated) Mapbox circle + polygon annotations once.
  /// Only called when the zone set actually changes — no blink on refresh.
  Future<void> _drawDangerZonesStatic() async {
    final circleManager = _heatmapCircleManager;
    final polygonManager = _dangerZonePolylineManager;
    if (circleManager == null || polygonManager == null) return;

    await circleManager.deleteAll();
    await polygonManager.deleteAll();
    _annotationZoneMap.clear();
    if (_currentDangerZones.isEmpty) return;

    for (final zone in _currentDangerZones) {
      final center = zone.center;
      if (center != null) {
        final colors = _threatColors(zone.threatLevel);
        final circleRadius = (zone.radius / 2.6).clamp(16.0, 58.0);
        final innerRadius = (zone.radius / 4 * 0.48).clamp(5.0, 16.0);

        final outer = await circleManager.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: center),
            circleRadius: circleRadius,
            circleColor: colors.fill.toARGB32(),
            circleStrokeColor: colors.stroke.toARGB32(),
            circleStrokeWidth: 2.0,
          ),
        );
        _annotationZoneMap[outer.id] = zone;

        final dot = await circleManager.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: center),
            circleRadius: innerRadius,
            circleColor: colors.stroke.toARGB32(),
            circleStrokeColor: const Color(0xDDFFFFFF).toARGB32(),
            circleStrokeWidth: 1.0,
          ),
        );
        _annotationZoneMap[dot.id] = zone;
      }

      if (zone.polygon.length >= 3) {
        final closed = <Position>[...zone.polygon, zone.polygon.first];
        await polygonManager.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: closed),
            lineColor: _threatColors(zone.threatLevel).stroke.toARGB32(),
            lineWidth: 3.0,
          ),
        );
      }
    }
  }

  /// Converts each zone centre to screen pixels using a synchronous Mercator
  /// projection so positions update in the same frame as a camera event.
  void _computeZoneScreenData(CameraState cs) {
    if (_mapSize == Size.zero || _currentDangerZones.isEmpty) {
      _zoneScreenDataNotifier.value = const [];
      return;
    }
    final centerLng = _toDouble(cs.center.coordinates.lng) ?? 0.0;
    final centerLat = _toDouble(cs.center.coordinates.lat) ?? 0.0;
    final zoom = cs.zoom.toDouble();
    final bearing = cs.bearing.toDouble();
    final newData = <_ZoneScreenData>[];
    for (final zone in _currentDangerZones) {
      if (zone.center == null) continue;
      final offset = _mercatorToScreen(
        _toDouble(zone.center!.lng) ?? 0.0,
        _toDouble(zone.center!.lat) ?? 0.0,
        centerLng,
        centerLat,
        zoom,
        bearing,
      );
      final radius = (zone.radius / 2.6).clamp(16.0, 58.0);
      final color = _threatColors(zone.threatLevel).ripple;
      newData.add(_ZoneScreenData(center: offset, radius: radius, color: color));
    }
    _zoneScreenDataNotifier.value = newData;
  }

  /// Mercator projection: lat/lng → screen pixel offset.
  /// Mapbox GL uses 512-px tiles; bearing is applied so the overlay
  /// matches the map even when the user rotates the view.
  Offset _mercatorToScreen(
    double lng,
    double lat,
    double centerLng,
    double centerLat,
    double zoom,
    double bearingDeg,
  ) {
    const tileSize = 512.0;
    final worldSize = tileSize * pow(2.0, zoom);

    double mercX(double l) => (l + 180.0) / 360.0;
    double mercY(double l) {
      final r = l * pi / 180.0;
      return (1.0 - log(tan(r) + 1.0 / cos(r)) / pi) / 2.0;
    }

    final dx = (mercX(lng) - mercX(centerLng)) * worldSize;
    final dy = (mercY(lat) - mercY(centerLat)) * worldSize;

    // Rotate for map bearing.
    final b = -bearingDeg * pi / 180.0;
    final rx = dx * cos(b) - dy * sin(b);
    final ry = dx * sin(b) + dy * cos(b);

    return Offset(_mapSize.width / 2 + rx, _mapSize.height / 2 + ry);
  }

  /// Async fallback used on first load / zone refresh (no camera event available).
  Future<void> _updateZoneScreenData() async {
    final map = _mapController;
    if (map == null || !mounted) return;
    final cs = await map.getCameraState();
    if (mounted) _computeZoneScreenData(cs);
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
        circleColor: Colors.blue.toARGB32(),
        circleRadius: 8.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.toARGB32(),
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
      _destWarningMessage = null;
      _selectedZone = null;
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

      final response = await _fetchSafeRoute(start, destination);

      if (response == null) {
        await drawRoute(start, destination);
        return;
      }

      // Render all zones from the response.
      if (response.allZones.isNotEmpty) {
        await _renderDangerZones(response.allZones);
      }

      // Destination is inside a danger zone — warn the user, do not route.
      if (response.destinationDangerous) {
        setState(() {
          _destWarningMessage = response.warningMessage;
        });
        final zone = response.destinationZone;
        if (zone?.center != null && _mapController != null) {
          await _mapController!.flyTo(
            CameraOptions(
              center: Point(coordinates: zone!.center!),
              zoom: 16.0,
            ),
            MapAnimationOptions(duration: 1200),
          );
        }
        return;
      }

      final payload = response.payload;
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
          _showSnackBar("Showing standard route for selected destination.");
          await drawRoute(start, destination);
          return;
        }
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
        _routeSourceLabel = 'Backend';
        _distanceText = distM > 0
            ? "Distance: ${(distM / 1000).toStringAsFixed(1)} km"
            : "Distance: --";
        _durationText = durS > 0
            ? "Estimated Time: ${(durS / 60).toStringAsFixed(0)} mins"
            : "Estimated Time: --";
        _hasActiveRoute = true;
      });
    }

    await _fitCameraToRouteAndZones(
      preferredRoute.path,
      fallbackCenter: markerTarget,
    );
  }

  int _routeColorValue(String colorName) {
    final color = colorName.trim().toLowerCase();
    switch (color) {
      case 'green':
        return const Color(0xFF1DB954).toARGB32();
      case 'red':
        return const Color(0xFFEF4444).toARGB32();
      case 'yellow':
        return const Color(0xFFFACC15).toARGB32();
      case 'orange':
        return const Color(0xFFF97316).toARGB32();
      case 'blue':
        return const Color(0xFF2962FF).toARGB32();
      case 'grey':
      case 'gray':
        return const Color(0xFF7E8A9A).toARGB32();
      default:
        return const Color(0xFF2962FF).toARGB32();
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
      lineColor: const Color(0xFF2962FF).toARGB32(),
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
        _routeSourceLabel = 'Standard';
        _distanceText = "Distance: ${(distM / 1000).toStringAsFixed(1)} km";
        _durationText =
            "Estimated Time: ${(durS / 60).toStringAsFixed(0)} mins";
        _hasActiveRoute = true;
      });
    }

    await _fitCameraToRouteAndZones(
      routeCoords,
      fallbackCenter: end,
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
        _routeSourceLabel = 'None';
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
              color: Colors.white.withValues(alpha: iconOpacity), size: iconSize),
        ),
      ),
    );
  }

  Widget _buildMapLegend() {
    final zonesOn = _currentDangerZones.isNotEmpty;
    final zoneCount = _currentDangerZones.length;
    final routeColor = _routeSourceLabel == 'Backend'
        ? const Color(0xFF1DB954)
        : (_routeSourceLabel == 'Standard'
            ? const Color(0xFF2962FF)
            : Colors.white70);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xCC102348),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(
                child: Text(
                  'Map Legend',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () =>
                    setState(() => _legendCollapsed = !_legendCollapsed),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _legendCollapsed
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          if (!_legendCollapsed) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xCCFF3B30),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Danger Zone',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 3,
                  decoration: BoxDecoration(
                    color: routeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _routeSourceLabel == 'Backend'
                      ? 'Backend Route'
                      : (_routeSourceLabel == 'Standard'
                          ? 'Standard Route'
                          : 'No Active Route'),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildLegendChip(
                    'Zones: ${zonesOn ? 'ON' : 'OFF'}',
                    zonesOn
                        ? const Color(0x44FF3B30)
                        : const Color(0x33FFFFFF)),
                _buildLegendChip(
                  'Count: $zoneCount',
                  zonesOn ? const Color(0x33FF3B30) : const Color(0x22FFFFFF),
                ),
                _buildLegendChip(
                  'Route: ${_routeSourceLabel == 'None' ? 'N/A' : _routeSourceLabel}',
                  _routeSourceLabel == 'Backend'
                      ? const Color(0x331DB954)
                      : (_routeSourceLabel == 'Standard'
                          ? const Color(0x332962FF)
                          : const Color(0x33FFFFFF)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendChip(String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Danger zone UI helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Client-side check: returns the first loaded zone the position falls inside.
  _DangerZone? _checkDestinationInDangerZone(Position dest) {
    for (final zone in _currentDangerZones) {
      if (zone.center == null) continue;
      final dist = _distanceMeters(dest, zone.center!);
      if (dist <= zone.radius) return zone;
    }
    return null;
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
    } catch (_) {
      return iso;
    }
  }

  Widget _zoneCardRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: Colors.white38),
        const SizedBox(width: 5),
        Text('$label: ',
            style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        ),
      ],
    );
  }

  Widget _buildZoneSummaryCard(_DangerZone zone) {
    final colors = _threatColors(zone.threatLevel);
    final accent = colors.stroke;
    final category = zone.issueTypes.isNotEmpty
        ? zone.issueTypes
            .map((s) => s[0].toUpperCase() + s.substring(1))
            .join(', ')
        : 'Danger Zone';
    final timeStr =
        zone.reportedAt != null ? _formatDateTime(zone.reportedAt!) : '—';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1C35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: accent, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(category,
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5)),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedZone = null),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white54, size: 15),
                ),
              ),
            ],
          ),
          if (zone.description != null && zone.description!.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(zone.description!,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12.5, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          _zoneCardRow(Icons.person_outline_rounded, 'Reported by',
              zone.reporter ?? '—'),
          const SizedBox(height: 5),
          _zoneCardRow(Icons.access_time_rounded, 'Time', timeStr),
        ],
      ),
    );
  }

  Widget _buildDestinationWarning() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0808),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xCCFF3B30).withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.red.withValues(alpha: 0.22),
              blurRadius: 20,
              spreadRadius: 1),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.dangerous_rounded,
                color: Color(0xFFFF3B30), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Dangerous Destination',
                    style: TextStyle(
                        color: Color(0xFFFF3B30),
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5)),
                const SizedBox(height: 5),
                Text(
                  _destWarningMessage ??
                      'Your destination is inside a danger zone. Avoid visiting this location.',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () =>
                setState(() => _destWarningMessage = null),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close,
                  color: Colors.white54, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Store map size for synchronous Mercator projection in camera listener.
    _mapSize = MediaQuery.of(context).size;
    // Top padding = status bar + AppBar height
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 12;

    return Scaffold(
      backgroundColor: AppColors.background,
      // extendBodyBehindAppBar lets the map fill the whole screen
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.background.withValues(alpha: 0.92),
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
                final cs = event.cameraState;
                // Synchronous Mercator projection — zero lag during scroll.
                _computeZoneScreenData(cs);
                if (!_isPickingDestination) return;
                _pendingPinnedPosition = _positionFromPoint(cs.center);
              },
              onMapIdleListener: (_) {
                _updateZoneScreenData();
                if (!mounted || !_isPickingDestination) return;
                setState(() {});
              },
              onMapCreated: _onMapCreated,
            ),
          ),

          // ── Ripple overlay — tracks pan in real-time via Mercator math ───
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RipplePainter(
                  zonesNotifier: _zoneScreenDataNotifier,
                  animation: _rippleController,
                ),
              ),
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
                color: const Color(0xFF102348).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
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
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                                color: Colors.white.withValues(alpha: 0.62)),
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
                                      color: Colors.white.withValues(alpha: 0.72),
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
                                          color: Colors.white.withValues(alpha: 0.72),
                                          size: 19,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _clearRoute,
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: Colors.white.withValues(alpha: 0.62),
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
                                          .withValues(alpha: 0.1),
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
                                    final destPos =
                                        fallbackLat is num && fallbackLng is num
                                            ? Position(fallbackLng.toDouble(),
                                                fallbackLat.toDouble())
                                            : null;
                                    _selectedDestinationPosition = destPos;
                                    _destinationController.text =
                                        _suggestionLabel(suggestion);
                                    setState(() {
                                      _destinationSuggestions = [];
                                      _hasActiveRoute = false;
                                      _destWarningMessage = null;
                                      _selectedZone = null;
                                    });
                                    _refreshSearchSessionToken();
                                    FocusScope.of(context).unfocus();
                                    // Preview: fly to destination + show pin.
                                    // Route is only drawn when the user presses
                                    // "Find Route".
                                    if (destPos != null) {
                                      await _showDestinationPin(destPos);
                                      await _moveCameraToPosition(destPos,
                                          zoom: 15.0);
                                      // Quick client-side danger check.
                                      final danger =
                                          _checkDestinationInDangerZone(
                                              destPos);
                                      if (danger != null && mounted) {
                                        setState(() {
                                          _destWarningMessage =
                                              '⚠️ This destination is inside a ${danger.threatLevel.toUpperCase()} danger zone. Avoid visiting this location.';
                                        });
                                      }
                                    }
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
                              color: Colors.white.withValues(alpha: 0.72), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _pinnedLocationLabel(_confirmedPinnedPosition!),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
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

          Positioned(
            left: 16,
            bottom: _sheetExtent > 0.17 ? 196 : 224,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _sheetExtent > 0.17 ? 0.88 : 1.0,
              child: _buildMapLegend(),
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
                  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
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

          // ── Zone summary card (tap on a danger zone) ─────────────────
          if (_selectedZone != null)
            Positioned(
              bottom: 180,
              left: 0,
              right: 0,
              child: _buildZoneSummaryCard(_selectedZone!),
            ),

          // ── Destination danger warning ────────────────────────────────
          if (_destWarningMessage != null)
            Positioned(
              bottom: _selectedZone != null ? 340 : 180,
              left: 0,
              right: 0,
              child: _buildDestinationWarning(),
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
                        shadowColor: Colors.black.withValues(alpha: 0.18),
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
                    color: AppColors.background.withValues(alpha: 0.96),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: AppColors.glassBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
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
                                color: AppColors.primary.withValues(alpha: 0.18)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.08),
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
                            color: AppColors.textSecondary.withValues(alpha: 0.92),
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

// ─────────────────────────────────────────────────────────────────────────────
// Ripple overlay painter
// ─────────────────────────────────────────────────────────────────────────────

class _ZoneScreenData {
  final Offset center;
  final double radius;
  final Color color;
  const _ZoneScreenData(
      {required this.center, required this.radius, required this.color});
}

class _RipplePainter extends CustomPainter {
  final ValueNotifier<List<_ZoneScreenData>> zonesNotifier;
  final Animation<double> animation;

  _RipplePainter({required this.zonesNotifier, required this.animation})
      : super(repaint: Listenable.merge([animation, zonesNotifier]));

  static const int _ringCount = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    for (final zone in zonesNotifier.value) {
      final c = zone.center;
      final baseRadius = zone.radius;
      final baseColor = zone.color;

      for (int i = 0; i < _ringCount; i++) {
        final phase = (t + i / _ringCount) % 1.0;
        final ringRadius = baseRadius + phase * baseRadius * 0.8;
        final opacity = (1.0 - phase) * 0.55;

        canvas.drawCircle(
          c,
          ringRadius,
          Paint()
            ..color = baseColor.withAlpha((opacity * 255).round())
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.zonesNotifier != zonesNotifier || old.animation != animation;
}

