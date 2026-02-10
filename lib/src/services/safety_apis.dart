import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'package:usafe_front_end/core/config/safety_api_config.dart';

/// Result of sunrise/sunset API. All times in UTC.
class SunriseSunsetResult {
  final DateTime sunriseUtc;
  final DateTime sunsetUtc;
  final bool isOk;

  const SunriseSunsetResult({
    required this.sunriseUtc,
    required this.sunsetUtc,
    required this.isOk,
  });

  /// Whether [nowUtc] is between sunset and sunrise (i.e. dark at location).
  bool isDarkAt(DateTime nowUtc) {
    if (!isOk) return false;
    return nowUtc.isBefore(sunriseUtc) || nowUtc.isAfter(sunsetUtc);
  }

  /// Risk 0-1 based on how far into "dark" we are (0 = daylight, 1 = middle of night).
  double darknessRisk(DateTime nowUtc) {
    if (!isOk) return 0.0;
    if (nowUtc.isAfter(sunriseUtc) && nowUtc.isBefore(sunsetUtc)) return 0.0;
    final nightStart = sunsetUtc;
    final nightEnd = sunriseUtc.isBefore(sunsetUtc)
        ? sunriseUtc.add(const Duration(days: 1))
        : sunriseUtc;
    final now = nowUtc.millisecondsSinceEpoch.toDouble();
    final start = nightStart.millisecondsSinceEpoch.toDouble();
    final end = nightEnd.millisecondsSinceEpoch.toDouble();
    final span = end - start;
    if (span <= 0) return 0.5;
    final intoNight = nowUtc.isAfter(sunsetUtc)
        ? (now - start) / span
        : (now + (24 * 3600 * 1000) - start) / span;
    if (intoNight <= 0 || intoNight >= 1) return 0.5;
    if (intoNight < 0.1) return intoNight / 0.1;
    if (intoNight > 0.9) return (1 - intoNight) / 0.1;
    return 1.0;
  }
}

/// Sunrise-Sunset.org API (free, no key).
/// https://api.sunrise-sunset.org/json
class SunriseSunsetApi {
  static const _base = 'https://api.sunrise-sunset.org/json';

  static Future<SunriseSunsetResult> getSunriseSunset({
    required double lat,
    required double lng,
    DateTime? date,
  }) async {
    final d = date ?? DateTime.now().toUtc();
    final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse('$_base?lat=$lat&lng=$lng&date=$dateStr&formatted=0');
    try {
      final resp = await http.get(uri).timeout(
        Duration(seconds: SafetyApiConfig.apiTimeoutSeconds),
      );
      if (resp.statusCode != 200) {
        return SunriseSunsetResult(sunriseUtc: DateTime.now().toUtc(), sunsetUtc: DateTime.now().toUtc(), isOk: false);
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status != 'OK') {
        return SunriseSunsetResult(sunriseUtc: DateTime.now().toUtc(), sunsetUtc: DateTime.now().toUtc(), isOk: false);
      }
      final results = data['results'] as Map<String, dynamic>?;
      if (results == null) {
        return SunriseSunsetResult(sunriseUtc: DateTime.now().toUtc(), sunsetUtc: DateTime.now().toUtc(), isOk: false);
      }
      final sunriseStr = results['sunrise'] as String?;
      final sunsetStr = results['sunset'] as String?;
      if (sunriseStr == null || sunsetStr == null) {
        return SunriseSunsetResult(sunriseUtc: DateTime.now().toUtc(), sunsetUtc: DateTime.now().toUtc(), isOk: false);
      }
      final sunriseUtc = DateTime.parse(sunriseStr).toUtc();
      final sunsetUtc = DateTime.parse(sunsetStr).toUtc();
      return SunriseSunsetResult(sunriseUtc: sunriseUtc, sunsetUtc: sunsetUtc, isOk: true);
    } catch (_) {
      return SunriseSunsetResult(sunriseUtc: DateTime.now().toUtc(), sunsetUtc: DateTime.now().toUtc(), isOk: false);
    }
  }
}

/// Nearest emergency POI (police or hospital) from OpenStreetMap.
class NearestHelpResult {
  final double distanceMeters;
  final String type; // 'police' | 'hospital'
  final bool isOk;

  const NearestHelpResult({required this.distanceMeters, required this.type, required this.isOk});
}

/// Result for nearest police station only (Sri Lanka: closest distance to police station).
class NearestPoliceResult {
  final double distanceMeters;
  final String? name;
  final bool isOk;

  const NearestPoliceResult({required this.distanceMeters, required this.isOk, this.name});
}

/// Result for nearest hospital only.
class NearestHospitalResult {
  final double distanceMeters;
  final String? name;
  final bool isOk;

  const NearestHospitalResult({required this.distanceMeters, required this.isOk, this.name});
}

/// Result for nearest embassy (high-value security proxy).
class NearestEmbassyResult {
  final double distanceMeters;
  final bool isOk;

  const NearestEmbassyResult({required this.distanceMeters, required this.isOk});
}

/// POI density: count of amenities in radius (proxy for "busy" area).
class PoiDensityResult {
  final int count;
  final bool isOk;

  const PoiDensityResult({required this.count, required this.isOk});
}

/// Road context from OpenStreetMap (nearest way).
class RoadContextResult {
  final bool? isSideLane;
  final bool? isWellLit;
  final bool isOk;

  const RoadContextResult({
    required this.isSideLane,
    required this.isWellLit,
    required this.isOk,
  });
}

/// Places density result (nearby Places count + area).
class PlacesDensityResult {
  final int count;
  final double areaKm2;
  final bool isOk;

  const PlacesDensityResult({
    required this.count,
    required this.areaKm2,
    required this.isOk,
  });
}

/// Open place count (open restaurants, cafes, malls, stores).
class OpenPlaceCountResult {
  final int count;
  final bool isOk;

  const OpenPlaceCountResult({required this.count, required this.isOk});
}

/// Traffic congestion estimate from Google Directions API.
/// congestion: 0.0 (free flow) -> 1.0 (heavy congestion)
class TrafficCongestionResult {
  final double congestion;
  final bool isOk;
  final double? durationRatio;

  const TrafficCongestionResult({
    required this.congestion,
    required this.isOk,
    this.durationRatio,
  });
}

/// Google Places API (New) - optional, requires API key.
/// https://developers.google.com/maps/documentation/places/web-service/search-nearby
class GooglePlacesApi {
  static const _endpoint = 'https://places.googleapis.com/v1/places:searchNearby';

  // A small, broad set of types that correlate with activity/crowd.
  static const List<String> _defaultTypes = [
    'restaurant',
    'cafe',
    'bar',
    'fast_food',
    'shopping_mall',
    'supermarket',
    'park',
    'school',
    'hospital',
    'transit_station',
    'tourist_attraction',
  ];

  static const List<String> _openNowTypes = [
    'restaurant',
    'cafe',
    'bar',
    'fast_food',
    'shopping_mall',
    'supermarket',
    'store',
  ];

  static Future<PlacesDensityResult> getPlaceDensity({
    required double lat,
    required double lng,
    int radiusMeters = 500,
  }) async {
    final apiKey = SafetyApiConfig.googlePlacesApiKey;
    final radius = radiusMeters.clamp(100, 1000);
    final areaKm2 = _circleAreaKm2(radius.toDouble());
    if (apiKey == null) {
      return PlacesDensityResult(count: 0, areaKm2: areaKm2, isOk: false);
    }

    final body = {
      'includedTypes': _defaultTypes,
      'maxResultCount': 50,
      'locationRestriction': {
        'circle': {
          'center': {'latitude': lat, 'longitude': lng},
          'radius': radius.toDouble(),
        },
      },
    };

    try {
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'places.id',
        },
        body: jsonEncode(body),
      ).timeout(Duration(seconds: SafetyApiConfig.apiTimeoutSeconds));

      if (resp.statusCode != 200) {
        return PlacesDensityResult(count: 0, areaKm2: areaKm2, isOk: false);
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final places = data['places'] as List<dynamic>? ?? [];
      return PlacesDensityResult(count: places.length, areaKm2: areaKm2, isOk: true);
    } catch (_) {
      return PlacesDensityResult(count: 0, areaKm2: areaKm2, isOk: false);
    }
  }

  static Future<OpenPlaceCountResult> getOpenPlaceCount({
    required double lat,
    required double lng,
    int radiusMeters = 800,
  }) async {
    final apiKey = SafetyApiConfig.googlePlacesApiKey;
    final radius = radiusMeters.clamp(200, 1500);
    if (apiKey == null) {
      return const OpenPlaceCountResult(count: 0, isOk: false);
    }

    final body = {
      'includedTypes': _openNowTypes,
      'maxResultCount': 50,
      'openNow': true,
      'locationRestriction': {
        'circle': {
          'center': {'latitude': lat, 'longitude': lng},
          'radius': radius.toDouble(),
        },
      },
    };

    try {
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'places.id',
        },
        body: jsonEncode(body),
      ).timeout(Duration(seconds: SafetyApiConfig.apiTimeoutSeconds));

      if (resp.statusCode != 200) {
        return const OpenPlaceCountResult(count: 0, isOk: false);
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final places = data['places'] as List<dynamic>? ?? [];
      return OpenPlaceCountResult(count: places.length, isOk: true);
    } catch (_) {
      return const OpenPlaceCountResult(count: 0, isOk: false);
    }
  }

  static double _circleAreaKm2(double radiusMeters) {
    final radiusKm = radiusMeters / 1000.0;
    return pi * radiusKm * radiusKm;
  }

  static Future<NearestPoliceResult> getNearestPolice({
    required double lat,
    required double lng,
    int radiusMeters = 10000,
  }) async {
    final result = await _getNearestByTypes(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      types: const ['police'],
    );
    if (!result.isOk) {
      return const NearestPoliceResult(distanceMeters: 5000, isOk: false);
    }
    return NearestPoliceResult(distanceMeters: result.distanceMeters, isOk: true, name: result.name);
  }

  static Future<NearestHospitalResult> getNearestHospital({
    required double lat,
    required double lng,
    int radiusMeters = 10000,
  }) async {
    final result = await _getNearestByTypes(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      types: const ['hospital'],
    );
    if (!result.isOk) {
      return const NearestHospitalResult(distanceMeters: 5000, isOk: false);
    }
    return NearestHospitalResult(distanceMeters: result.distanceMeters, isOk: true, name: result.name);
  }

  static Future<_NearestPlaceResult> _getNearestByTypes({
    required double lat,
    required double lng,
    required int radiusMeters,
    required List<String> types,
  }) async {
    final apiKey = SafetyApiConfig.googlePlacesApiKey;
    final radius = radiusMeters.clamp(100, 10000);
    if (apiKey == null) {
      return const _NearestPlaceResult(distanceMeters: 5000, isOk: false);
    }

    final body = {
      'includedTypes': types,
      'maxResultCount': 20,
      'locationRestriction': {
        'circle': {
          'center': {'latitude': lat, 'longitude': lng},
          'radius': radius.toDouble(),
        },
      },
    };

    try {
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'places.location,places.displayName',
        },
        body: jsonEncode(body),
      ).timeout(Duration(seconds: SafetyApiConfig.apiTimeoutSeconds));

      if (resp.statusCode != 200) {
        return const _NearestPlaceResult(distanceMeters: 5000, isOk: false);
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final places = data['places'] as List<dynamic>? ?? [];
      double minDist = double.infinity;
      String? nearestName;
      for (final p in places) {
        final place = p as Map<String, dynamic>;
        final loc = place['location'] as Map<String, dynamic>?;
        final plat = (loc?['latitude'] as num?)?.toDouble();
        final plng = (loc?['longitude'] as num?)?.toDouble();
        if (plat == null || plng == null) continue;
        final d = _haversineMeters(lat, lng, plat, plng);
        if (d < minDist) {
          minDist = d;
          final displayName = place['displayName'] as Map<String, dynamic>?;
          nearestName = displayName?['text'] as String?;
        }
      }

      if (minDist == double.infinity) {
        return const _NearestPlaceResult(distanceMeters: 5000, isOk: false);
      }

      return _NearestPlaceResult(distanceMeters: minDist, isOk: true, name: nearestName);
    } catch (_) {
      return const _NearestPlaceResult(distanceMeters: 5000, isOk: false);
    }
  }

  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _rad(double deg) => deg * pi / 180;
}

class _NearestPlaceResult {
  final double distanceMeters;
  final String? name;
  final bool isOk;

  const _NearestPlaceResult({required this.distanceMeters, required this.isOk, this.name});
}

/// Google Directions API - traffic proxy.
/// https://developers.google.com/maps/documentation/directions/get-directions
class GoogleTrafficApi {
  static const _endpoint = 'https://maps.googleapis.com/maps/api/directions/json';

  static Future<TrafficCongestionResult> getTrafficCongestion({
    required double lat,
    required double lng,
  }) async {
    final apiKey = SafetyApiConfig.googleMapsApiKey;
    if (apiKey == null) {
      return const TrafficCongestionResult(congestion: 0.0, isOk: false);
    }

    final offsets = const [
      {'lat': 0.01, 'lng': 0.0},
      {'lat': 0.0, 'lng': 0.01},
      {'lat': -0.01, 'lng': 0.0},
    ];

    for (final offset in offsets) {
      final destLat = lat + (offset['lat'] as double);
      final destLng = lng + (offset['lng'] as double);
      final ratio = await _fetchTrafficRatio(
        originLat: lat,
        originLng: lng,
        destLat: destLat,
        destLng: destLng,
        apiKey: apiKey,
      );
      if (ratio != null) {
        final congestion = ((ratio - 1.0) / 1.0).clamp(0.0, 1.0);
        return TrafficCongestionResult(
          congestion: congestion,
          isOk: true,
          durationRatio: ratio,
        );
      }
    }

    return const TrafficCongestionResult(congestion: 0.0, isOk: false);
  }

  static Future<double?> _fetchTrafficRatio({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String apiKey,
  }) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'origin': '$originLat,$originLng',
      'destination': '$destLat,$destLng',
      'departure_time': 'now',
      'traffic_model': 'best_guess',
      'mode': 'driving',
      'key': apiKey,
    });

    try {
      final resp = await http.get(uri).timeout(
        Duration(seconds: SafetyApiConfig.apiTimeoutSeconds),
      );
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status != 'OK') return null;
      final routes = data['routes'] as List<dynamic>? ?? [];
      if (routes.isEmpty) return null;
      final legs = (routes[0] as Map<String, dynamic>)['legs'] as List<dynamic>? ?? [];
      if (legs.isEmpty) return null;
      final leg = legs[0] as Map<String, dynamic>;
      final duration = (leg['duration'] as Map<String, dynamic>?)?['value'] as num?;
      final durationTraffic = (leg['duration_in_traffic'] as Map<String, dynamic>?)?['value'] as num?;
      if (duration == null || durationTraffic == null || duration <= 0) return null;
      return durationTraffic / duration;
    } catch (_) {
      return null;
    }
  }
}


/// Overpass API (OpenStreetMap) - free, no key.
/// https://wiki.openstreetmap.org/wiki/Overpass_API
class OverpassApi {
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.nchc.org.tw/api/interpreter',
  ];

  static Future<http.Response?> _postOverpass(String query) async {
    for (final endpoint in _endpoints) {
      try {
        final resp = await http.post(
          Uri.parse(endpoint),
          body: {'data': query},
          headers: {
            'User-Agent': 'usafe_front_end/1.0',
          },
        ).timeout(Duration(seconds: SafetyApiConfig.apiTimeoutSeconds));
        if (resp.statusCode == 200) return resp;
        if (resp.statusCode >= 500 || resp.statusCode == 429) {
          continue;
        }
        return resp;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Find nearest police station only (for Sri Lanka: closest distance to police station).
  static Future<NearestPoliceResult> getNearestPoliceStation({
    required double lat,
    required double lng,
    int radiusMeters = 10000,
  }) async {
    final radius = radiusMeters.clamp(500, 30000);
    final query = '''
[out:json][timeout:15];
(
  node(around:$radius,$lat,$lng)[amenity=police];
  way(around:$radius,$lat,$lng)[amenity=police];
);
out center;
''';
    try {
      final resp = await _postOverpass(query);
      if (resp == null || resp.statusCode != 200) {
        return const NearestPoliceResult(distanceMeters: 5000, isOk: false);
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>? ?? [];
      double minDist = double.infinity;
      String? nearestName;
      for (final el in elements) {
        final e = el as Map<String, dynamic>;
        double? elat, elon;
        if (e['lat'] != null && e['lon'] != null) {
          elat = (e['lat'] as num).toDouble();
          elon = (e['lon'] as num).toDouble();
        } else if (e['center'] != null) {
          final c = e['center'] as Map<String, dynamic>;
          elat = (c['lat'] as num).toDouble();
          elon = (c['lon'] as num).toDouble();
        }
        if (elat != null && elon != null) {
          final d = _haversineMeters(lat, lng, elat, elon);
          if (d < minDist) {
            minDist = d;
            final tags = e['tags'] as Map<String, dynamic>? ?? {};
            nearestName = tags['name'] as String?;
          }
        }
      }
      if (minDist == double.infinity) {
        return const NearestPoliceResult(distanceMeters: 5000, isOk: false);
      }
      return NearestPoliceResult(distanceMeters: minDist, isOk: true, name: nearestName);
    } catch (_) {
      return const NearestPoliceResult(distanceMeters: 5000, isOk: false);
    }
  }

  /// Find nearest hospital only.
  static Future<NearestHospitalResult> getNearestHospital({
    required double lat,
    required double lng,
    int radiusMeters = 10000,
  }) async {
    final radius = radiusMeters.clamp(500, 30000);
    final query = '''
[out:json][timeout:15];
(
  node(around:$radius,$lat,$lng)[amenity=hospital];
  way(around:$radius,$lat,$lng)[amenity=hospital];
);
out center;
''';
    try {
      final resp = await _postOverpass(query);
      if (resp == null || resp.statusCode != 200) {
        return const NearestHospitalResult(distanceMeters: 5000, isOk: false);
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>? ?? [];
      double minDist = double.infinity;
      String? nearestName;
      for (final el in elements) {
        final e = el as Map<String, dynamic>;
        double? elat, elon;
        if (e['lat'] != null && e['lon'] != null) {
          elat = (e['lat'] as num).toDouble();
          elon = (e['lon'] as num).toDouble();
        } else if (e['center'] != null) {
          final c = e['center'] as Map<String, dynamic>;
          elat = (c['lat'] as num).toDouble();
          elon = (c['lon'] as num).toDouble();
        }
        if (elat != null && elon != null) {
          final d = _haversineMeters(lat, lng, elat, elon);
          if (d < minDist) {
            minDist = d;
            final tags = e['tags'] as Map<String, dynamic>? ?? {};
            nearestName = tags['name'] as String?;
          }
        }
      }
      if (minDist == double.infinity) {
        return const NearestHospitalResult(distanceMeters: 5000, isOk: false);
      }
      return NearestHospitalResult(distanceMeters: minDist, isOk: true, name: nearestName);
    } catch (_) {
      return const NearestHospitalResult(distanceMeters: 5000, isOk: false);
    }
  }

  /// Find nearest police station or hospital within [radiusMeters].
  static Future<NearestHelpResult> getNearestPoliceOrHospital({
    required double lat,
    required double lng,
    int radiusMeters = 5000,
  }) async {
    final radius = radiusMeters.clamp(100, 20000);
    // Query: nodes with amenity=police or amenity=hospital within radius.
    final query = '''
[out:json][timeout:15];
(
  node(around:$radius,$lat,$lng)[amenity=police];
  node(around:$radius,$lat,$lng)[amenity=hospital];
  way(around:$radius,$lat,$lng)[amenity=police];
  way(around:$radius,$lat,$lng)[amenity=hospital];
);
out center;
''';
    final q = query;
    try {
      final resp = await _postOverpass(q);
      if (resp == null || resp.statusCode != 200) {
        return const NearestHelpResult(distanceMeters: 5000, type: 'none', isOk: false);
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>? ?? [];
      double minDist = double.infinity;
      String type = 'none';
      for (final el in elements) {
        final e = el as Map<String, dynamic>;
        double? elat, elon;
        if (e['lat'] != null && e['lon'] != null) {
          elat = (e['lat'] as num).toDouble();
          elon = (e['lon'] as num).toDouble();
        } else if (e['center'] != null) {
          final c = e['center'] as Map<String, dynamic>;
          elat = (c['lat'] as num).toDouble();
          elon = (c['lon'] as num).toDouble();
        }
        if (elat != null && elon != null) {
          final d = _haversineMeters(lat, lng, elat, elon);
          if (d < minDist) {
            minDist = d;
            final tags = e['tags'] as Map<String, dynamic>? ?? {};
            type = tags['amenity'] == 'hospital' ? 'hospital' : 'police';
          }
        }
      }
      if (minDist == double.infinity) {
        return const NearestHelpResult(distanceMeters: 5000, type: 'none', isOk: false);
      }
      return NearestHelpResult(distanceMeters: minDist, type: type, isOk: true);
    } catch (_) {
      return const NearestHelpResult(distanceMeters: 5000, type: 'none', isOk: false);
    }
  }

  /// Find nearest embassy within [radiusMeters].
  static Future<NearestEmbassyResult> getNearestEmbassy({
    required double lat,
    required double lng,
    int radiusMeters = 5000,
  }) async {
    final radius = radiusMeters.clamp(500, 20000);
    final query = '''
[out:json][timeout:15];
(
  node(around:$radius,$lat,$lng)[amenity=embassy];
  way(around:$radius,$lat,$lng)[amenity=embassy]);
out center;
''';
    try {
      final resp = await _postOverpass(query);
      if (resp == null || resp.statusCode != 200) {
        return const NearestEmbassyResult(distanceMeters: 5000, isOk: false);
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>? ?? [];
      double minDist = double.infinity;
      for (final el in elements) {
        final e = el as Map<String, dynamic>;
        double? elat, elon;
        if (e['lat'] != null && e['lon'] != null) {
          elat = (e['lat'] as num).toDouble();
          elon = (e['lon'] as num).toDouble();
        } else if (e['center'] != null) {
          final c = e['center'] as Map<String, dynamic>;
          elat = (c['lat'] as num).toDouble();
          elon = (c['lon'] as num).toDouble();
        }
        if (elat != null && elon != null) {
          final d = _haversineMeters(lat, lng, elat, elon);
          if (d < minDist) minDist = d;
        }
      }
      if (minDist == double.infinity) {
        return const NearestEmbassyResult(distanceMeters: 5000, isOk: false);
      }
      return NearestEmbassyResult(distanceMeters: minDist, isOk: true);
    } catch (_) {
      return const NearestEmbassyResult(distanceMeters: 5000, isOk: false);
    }
  }

  /// Count POIs (restaurants, cafes, shops) in radius as proxy for crowd/activity.
  static Future<PoiDensityResult> getPoiDensity({
    required double lat,
    required double lng,
    int radiusMeters = 500,
  }) async {
    final radius = radiusMeters.clamp(200, 1500);
    final query = '''
[out:json][timeout:12];
(
  node(around:$radius,$lat,$lng)[amenity~"restaurant|cafe|bar|fast_food|pub"];
  node(around:$radius,$lat,$lng)[shop~"convenience|supermarket|mall"];
  node(around:$radius,$lat,$lng)[tourism~"attraction|museum|theme_park"]);
out ids;
''';
    final q = query;
    try {
      final resp = await _postOverpass(q);
      if (resp == null || resp.statusCode != 200) {
        return const PoiDensityResult(count: 0, isOk: false);
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>? ?? [];
      final count = elements.length;
      // Normalize to 0-1 proxy: 0 POIs = isolated, 20+ = busy. We'll map in provider.
      return PoiDensityResult(count: count, isOk: true);
    } catch (_) {
      return const PoiDensityResult(count: 0, isOk: false);
    }
  }

  /// Nearest road context (highway type + lighting). Useful for side-lane/lighting penalty.
  static Future<RoadContextResult> getRoadContext({
    required double lat,
    required double lng,
    int radiusMeters = 250,
  }) async {
    final radius = radiusMeters.clamp(100, 800);
    final query = '''
[out:json][timeout:12];
way(around:$radius,$lat,$lng)[highway];
out tags center;
''';
    try {
      final resp = await _postOverpass(query);
      if (resp == null || resp.statusCode != 200) {
        return const RoadContextResult(isSideLane: null, isWellLit: null, isOk: false);
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>? ?? [];
      double minDist = double.infinity;
      Map<String, dynamic>? bestTags;
      for (final el in elements) {
        final e = el as Map<String, dynamic>;
        final center = e['center'] as Map<String, dynamic>?;
        final elat = (center?['lat'] as num?)?.toDouble();
        final elon = (center?['lon'] as num?)?.toDouble();
        if (elat == null || elon == null) continue;
        final d = _haversineMeters(lat, lng, elat, elon);
        if (d < minDist) {
          minDist = d;
          bestTags = e['tags'] as Map<String, dynamic>?;
        }
      }

      if (bestTags == null) {
        return const RoadContextResult(isSideLane: null, isWellLit: null, isOk: false);
      }

      final highway = (bestTags['highway'] as String?)?.toLowerCase();
      final lit = (bestTags['lit'] as String?)?.toLowerCase();

      final isMainRoad = _isMainRoadType(highway);
      final isSideLane = highway == null ? null : !isMainRoad;
      final isWellLit = lit == null ? null : _isTruthy(lit);

      return RoadContextResult(isSideLane: isSideLane, isWellLit: isWellLit, isOk: true);
    } catch (_) {
      return const RoadContextResult(isSideLane: null, isWellLit: null, isOk: false);
    }
  }

  static bool _isMainRoadType(String? highway) {
    if (highway == null) return false;
    const main = {
      'motorway',
      'trunk',
      'primary',
      'secondary',
      'tertiary',
    };
    return main.contains(highway);
  }

  static bool _isTruthy(String value) {
    return value == 'yes' || value == 'true' || value == '1';
  }

  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _rad(double deg) => deg * pi / 180;
}

/// Crime count result (from UK Police or Crimeometer).
class CrimeCountResult {
  final int incidentCount;
  final bool isOk;
  final String? source; // 'uk_police' | 'crimeometer' | null if fallback

  const CrimeCountResult({required this.incidentCount, required this.isOk, this.source});
}

/// UK Police API (data.police.uk) - free, no key. England, Wales, Northern Ireland.
class UkPoliceApi {
  static const _base = 'https://data.police.uk/api/crimes-at-location';

  static Future<CrimeCountResult> getCrimeCountAt({
    required double lat,
    required double lng,
    int monthsBack = 6,
  }) async {
    if (!SafetyApiConfig.isInUk(lat, lng)) {
      return const CrimeCountResult(incidentCount: 0, isOk: false, source: null);
    }
    int total = 0;
    final now = DateTime.now().toUtc();
    for (int i = 0; i < monthsBack; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final uri = Uri.parse('$_base?lat=$lat&lng=$lng&date=$dateStr');
      try {
        final resp = await http.get(uri).timeout(
          const Duration(seconds: 10),
        );
        if (resp.statusCode == 200) {
          final list = jsonDecode(resp.body) as List<dynamic>;
          total += list.length;
        }
      } catch (_) {
        break;
      }
    }
    return CrimeCountResult(incidentCount: total, isOk: true, source: 'uk_police');
  }
}

/// Crimeometer API - requires API key. US and worldwide.
/// https://www.crimeometer.com/docs
class CrimeometerApi {
  static const _base = 'https://api.crimeometer.com/v2/incidents/stats';

  static Future<CrimeCountResult> getCrimeStatsAt({
    required double lat,
    required double lng,
    double distanceMiles = 0.5,
    int daysBack = 90,
  }) async {
    final key = SafetyApiConfig.crimeometerApiKey;
    if (key == null || key.isEmpty) {
      return const CrimeCountResult(incidentCount: 0, isOk: false, source: null);
    }
    final end = DateTime.now();
    final start = end.subtract(Duration(days: daysBack));
    final uri = Uri.parse(_base).replace(queryParameters: {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'datetime_ini': start.toIso8601String(),
      'datetime_end': end.toIso8601String(),
      'distance': distanceMiles.toString(),
    });
    try {
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': key,
        },
      ).timeout(Duration(seconds: SafetyApiConfig.apiTimeoutSeconds));
      if (resp.statusCode != 200) {
        return const CrimeCountResult(incidentCount: 0, isOk: false, source: null);
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final total = (data['total_incidents'] as num?)?.toInt() ?? 0;
      return CrimeCountResult(incidentCount: total, isOk: true, source: 'crimeometer');
    } catch (_) {
      return const CrimeCountResult(incidentCount: 0, isOk: false, source: null);
    }
  }
}
