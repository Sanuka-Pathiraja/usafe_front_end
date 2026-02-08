import 'dart:math';

import 'package:usafe_front_end/core/config/safety_api_config.dart';
import 'package:usafe_front_end/core/config/sri_lanka_config.dart';
import 'package:usafe_front_end/src/services/safety_apis.dart';
import 'package:usafe_front_end/src/services/sri_lanka_safety_data.dart';

/// Position for score calculation (avoids direct map dependency).
class SafetyPosition {
  final double latitude;
  final double longitude;
  const SafetyPosition(this.latitude, this.longitude);
}

/// Result of the live safety score calculation.
/// Score 12-92: higher = safer. Zone drives UI and active triggers.
class LiveSafetyScoreResult {
  final int score;
  final SafetyZone zone;
  final String label;
  final PillarBreakdown breakdown;
  final SafetyScoreDebugInfo? debugInfo;

  const LiveSafetyScoreResult({
    required this.score,
    required this.zone,
    required this.label,
    required this.breakdown,
    this.debugInfo,
  });

  bool get isDanger => zone == SafetyZone.danger;
  bool get isCaution => zone == SafetyZone.caution;
  bool get isSafe => zone == SafetyZone.safe;
}

enum SafetyZone { safe, caution, danger }

/// Detailed calculation values for UI/debug.
class SafetyScoreDebugInfo {
  final double latitude;
  final double longitude;
  final String? districtName;
  final int timePenalty;
  final int infraPenalty;
  final int isolationPenalty;
  final int weatherPenalty;
  final int historyPenalty;
  final int distanceBonus;
  final int crowdBonus;
  final int embassyBonus;
  final int totalPenalties;
  final int totalMitigations;
  final double crowdDensity;
  final int nearbyVenueCount;
  final double distanceToHelpMeters;
  final bool? isSideLane;
  final bool? isWellLit;
  final bool? isNearEmbassy;

  const SafetyScoreDebugInfo({
    required this.latitude,
    required this.longitude,
    required this.districtName,
    required this.timePenalty,
    required this.infraPenalty,
    required this.isolationPenalty,
    required this.weatherPenalty,
    required this.historyPenalty,
    required this.distanceBonus,
    required this.crowdBonus,
    required this.embassyBonus,
    required this.totalPenalties,
    required this.totalMitigations,
    required this.crowdDensity,
    required this.nearbyVenueCount,
    required this.distanceToHelpMeters,
    required this.isSideLane,
    required this.isWellLit,
    required this.isNearEmbassy,
  });
}

/// Per-pillar contribution for transparency in UI.
/// Sri Lanka: time of day, population density, distance to police, past incidents (Sri Lanka data only).
class PillarBreakdown {
  final double timeLight;       // 0-1 risk (0 = day, 1 = night)
  final double environment;      // 0-1 risk from low population density (isolation)
  final double history;         // 0-1 risk from past incidents (Sri Lanka records)
  final double proximity;       // 0-1 risk from distance to police station

  const PillarBreakdown({
    required this.timeLight,
    required this.environment,
    required this.history,
    required this.proximity,
  });
}

/// Data inputs for the four pillars. Filled from external APIs / Sri Lanka data.
class SafetyScoreInputs {
  final DateTime dateTime;
  final SafetyPosition position;
  /// 0 = isolated/low density, 1 = high population density (safety factor). Sri Lanka: district + POI.
  final double crowdDensity;
  /// Optional: nearby venue count used as a proxy for open shops/cafes.
  final int nearbyVenueCount;
  /// Optional: indicates whether the nearest road is a side lane.
  final bool? isSideLane;
  /// Optional: indicates if the nearest road is well lit (OSM lit=yes/no).
  final bool? isWellLit;
  /// Optional: indicates if an embassy is nearby (high-value security).
  final bool? isNearEmbassy;
  /// Past incidents: count (foreign APIs) or use [incidentRiskOverride] for Sri Lanka.
  final int incidentCount;
  /// Distance in meters to nearest help (police or hospital). Smaller = safer.
  final double distanceToHelpMeters;
  /// When set, overrides time/light (0 = day, 1 = night). From sunrise-sunset API.
  final double? timeLightRiskOverride;
  /// When set (Sri Lanka), overrides history pillar (0 = safe, 1 = risky). From Sri Lanka records only.
  final double? incidentRiskOverride;

  const SafetyScoreInputs({
    required this.dateTime,
    required this.position,
    this.crowdDensity = 0.5,
    this.nearbyVenueCount = 0,
    this.isSideLane,
    this.isWellLit,
    this.isNearEmbassy,
    this.incidentCount = 0,
    this.distanceToHelpMeters = 1000,
    this.timeLightRiskOverride,
    this.incidentRiskOverride,
  });
}

/// Live Safety Score engine: four pillars + mitigation model.
/// When score drops below threshold (danger zone), the app should
/// "automatically sharpen monitoring" (warm start audio/motion).
class LiveSafetyScoreService {
  static const int thresholdSafe = 65;   // >= 65: Green
  static const int thresholdCaution = 35; // 35-64: Orange
  static const int minScore = 12; // Never show 0 to avoid false certainty.
  static const int maxScore = 92; // Never show 100 to avoid false assurance.

  static const List<_SriLankaAreaTuning> _slTunings = [
    _SriLankaAreaTuning(
      name: 'Kollupitiya',
      lat: 6.9006,
      lng: 79.8533,
      radiusMeters: 1200,
      priority: 1,
      crowdFloor: 0.65,
      baseBonusDay: 4.0,
      baseBonusNight: 3.0,
      crowdBonusBoost: 4.0,
      timeRefundBoost: 0.10,
      nightIsolationPenalty: 0.0,
    ),
    _SriLankaAreaTuning(
      name: 'Wellawatte',
      lat: 6.8744,
      lng: 79.8605,
      radiusMeters: 1300,
      priority: 1,
      crowdFloor: 0.6,
      baseBonusDay: 2.0,
      baseBonusNight: 2.0,
      crowdBonusBoost: 3.0,
      timeRefundBoost: 0.05,
      nightIsolationPenalty: 0.0,
    ),
    _SriLankaAreaTuning(
      name: 'Havelock Town',
      lat: 6.8861,
      lng: 79.8625,
      radiusMeters: 1200,
      priority: 1,
      crowdFloor: 0.45,
      baseBonusDay: 0.0,
      baseBonusNight: -2.0,
      crowdBonusBoost: 0.0,
      timeRefundBoost: 0.0,
      nightIsolationPenalty: 6.0,
    ),
    _SriLankaAreaTuning(
      name: 'Kuruduwatta',
      lat: 6.9098,
      lng: 79.8691,
      radiusMeters: 1200,
      priority: 1,
      crowdFloor: 0.55,
      baseBonusDay: 5.0,
      baseBonusNight: 2.0,
      crowdBonusBoost: 2.0,
      timeRefundBoost: 0.15,
      nightIsolationPenalty: 0.0,
    ),
    _SriLankaAreaTuning(
      name: 'Bambalapitiya',
      lat: 6.8914,
      lng: 79.8522,
      radiusMeters: 1400,
      priority: 1,
      crowdFloor: 0.45,
      baseBonusDay: 0.0,
      baseBonusNight: 0.0,
      crowdBonusBoost: 0.0,
      timeRefundBoost: 0.0,
      nightIsolationPenalty: 6.0,
    ),
    _SriLankaAreaTuning(
      name: 'Galle Road (Bambalapitiya)',
      lat: 6.8914,
      lng: 79.8522,
      radiusMeters: 450,
      priority: 2,
      crowdFloor: 0.7,
      baseBonusDay: 4.0,
      baseBonusNight: 3.0,
      crowdBonusBoost: 4.0,
      timeRefundBoost: 0.05,
      nightIsolationPenalty: 0.0,
    ),
    _SriLankaAreaTuning(
      name: 'Marine Drive',
      lat: 6.8920,
      lng: 79.8510,
      radiusMeters: 450,
      priority: 2,
      crowdFloor: 0.35,
      baseBonusDay: 0.0,
      baseBonusNight: -4.0,
      crowdBonusBoost: 0.0,
      timeRefundBoost: 0.0,
      nightIsolationPenalty: 10.0,
    ),
    _SriLankaAreaTuning(
      name: 'Duplication Road',
      lat: 6.8915,
      lng: 79.8545,
      radiusMeters: 500,
      priority: 2,
      crowdFloor: 0.5,
      baseBonusDay: 1.0,
      baseBonusNight: -1.0,
      crowdBonusBoost: 1.0,
      timeRefundBoost: 0.0,
      nightIsolationPenalty: 5.0,
    ),
    _SriLankaAreaTuning(
      name: 'Vajira Road',
      lat: 6.8916,
      lng: 79.8613,
      radiusMeters: 450,
      priority: 2,
      crowdFloor: 0.4,
      baseBonusDay: 0.0,
      baseBonusNight: -2.0,
      crowdBonusBoost: 0.0,
      timeRefundBoost: 0.0,
      nightIsolationPenalty: 8.0,
    ),
    _SriLankaAreaTuning(
      name: 'Dickmans Road',
      lat: 6.8890,
      lng: 79.8580,
      radiusMeters: 450,
      priority: 2,
      crowdFloor: 0.4,
      baseBonusDay: 0.0,
      baseBonusNight: -2.0,
      crowdBonusBoost: 0.0,
      timeRefundBoost: 0.0,
      nightIsolationPenalty: 8.0,
    ),
  ];

  /// Returns a score 12-92 and zone. Uses penalties + mitigation model.
  LiveSafetyScoreResult calculate(SafetyScoreInputs inputs) {
    final b = _computePillarBreakdown(inputs);
    final double base = maxScore.toDouble();

    final timePenalty = _timePenalty(inputs.dateTime);
    final infraPenalty = _lightingPenalty(inputs.isSideLane, inputs.isWellLit);
    final isolationPenalty = _isolationPenalty(inputs.crowdDensity, inputs.nearbyVenueCount);
    final weatherPenalty = 0;
    final historyPenalty = _historyPenalty(b.history);

    final distanceBonus = _policeBonus(inputs.distanceToHelpMeters);
    final crowdBonus = _crowdBonus(inputs.nearbyVenueCount);
    final embassyBonus = inputs.isNearEmbassy == true ? 15 : 0;

    final penalties = timePenalty + infraPenalty + isolationPenalty + weatherPenalty + historyPenalty;
    final mitigations = distanceBonus + crowdBonus + embassyBonus;

    double score = base - penalties + mitigations;

    score = score.clamp(minScore.toDouble(), maxScore.toDouble());
    final intScore = score.round().clamp(minScore, maxScore);

    SafetyZone zone;
    String label;
    if (intScore >= thresholdSafe) {
      zone = SafetyZone.safe;
      label = 'Safe';
    } else if (intScore >= thresholdCaution) {
      zone = SafetyZone.caution;
      label = 'Caution';
    } else {
      zone = SafetyZone.danger;
      label = 'Danger';
    }

    return LiveSafetyScoreResult(
      score: intScore,
      zone: zone,
      label: label,
      breakdown: b,
      debugInfo: SafetyScoreDebugInfo(
        latitude: inputs.position.latitude,
        longitude: inputs.position.longitude,
        districtName: SriLankaSafetyData
            .getDistrictFor(inputs.position.latitude, inputs.position.longitude)
            ?.name,
        timePenalty: timePenalty,
        infraPenalty: infraPenalty,
        isolationPenalty: isolationPenalty,
        weatherPenalty: weatherPenalty,
        historyPenalty: historyPenalty,
        distanceBonus: distanceBonus,
        crowdBonus: crowdBonus,
        embassyBonus: embassyBonus,
        totalPenalties: penalties,
        totalMitigations: mitigations,
        crowdDensity: inputs.crowdDensity,
        nearbyVenueCount: inputs.nearbyVenueCount,
        distanceToHelpMeters: inputs.distanceToHelpMeters,
        isSideLane: inputs.isSideLane,
        isWellLit: inputs.isWellLit,
        isNearEmbassy: inputs.isNearEmbassy,
      ),
    );
  }

  int _timePenalty(DateTime dateTime) {
    final hour = dateTime.hour + dateTime.minute / 60.0;
    if (hour >= 22 || hour < 4) return 30;
    if (hour >= 18 || hour < 22) return 10;
    if (hour >= 4 && hour < 6) return 15;
    return 0;
  }

  int _lightingPenalty(bool? isSideLane, bool? isWellLit) {
    if (isSideLane == true && isWellLit == false) return 15;
    if (isSideLane == true && isWellLit == true) return 5;
    return 0;
  }

  int _historyPenalty(double historyRisk) {
    if (historyRisk >= 0.66) return 20;
    if (historyRisk >= 0.33) return 10;
    return 0;
  }

  int _policeBonus(double distanceMeters) {
    if (distanceMeters <= 200) return 25;
    if (distanceMeters <= 500) return 15;
    if (distanceMeters <= 1000) return 5;
    return 0;
  }

  int _crowdBonus(int venueCount) {
    if (venueCount > 5) return 15;
    if (venueCount >= 1) return 5;
    return 0;
  }

  int _isolationPenalty(double crowdDensity, int venueCount) {
    if (crowdDensity < 0.1 && venueCount == 0) return 25;
    if (crowdDensity < 0.25) return 15;
    return 0;
  }

  PillarBreakdown _computePillarBreakdown(SafetyScoreInputs i) {
    final timeLight = i.timeLightRiskOverride ?? _pillarTimeAndLight(i.dateTime, i.position);
    final environment = _pillarEnvironment(i.crowdDensity);
    final history = i.incidentRiskOverride ?? _pillarHistory(i.incidentCount);
    final proximity = _pillarProximity(i.distanceToHelpMeters);
    return PillarBreakdown(
      timeLight: timeLight,
      environment: environment,
      history: history,
      proximity: proximity,
    );
  }

  /// Contextual: risk increases after dark. 0 = day (safe), 1 = night (risk).
  double _pillarTimeAndLight(DateTime dateTime, SafetyPosition position) {
    final hour = dateTime.hour + dateTime.minute / 60.0;
    // Simple heuristic: dark roughly 18:00–06:00. Can be replaced with suncalc.
    const double sunsetHour = 18.0;
    const double sunriseHour = 6.0;
    bool isDark = hour >= sunsetHour || hour < sunriseHour;
    if (!isDark) return 0.0;
    // Twilight: ramp risk in first/last hour of night.
    if (hour >= sunsetHour && hour < sunsetHour + 1) {
      return (hour - sunsetHour); // 0 -> 1 over first hour
    }
    if (hour >= sunriseHour - 1 && hour < sunriseHour) {
      return (sunriseHour - hour); // 1 -> 0 over last hour
    }
    return 1.0;
  }

  /// Environmental: isolation = risk. crowdDensity 0 = isolated (1), 1 = crowded (0).
  double _pillarEnvironment(double crowdDensity) {
    return (1.0 - crowdDensity).clamp(0.0, 1.0);
  }

  /// History: more past incidents = higher risk. Cap at 20 for scaling.
  double _pillarHistory(int incidentCount) {
    if (incidentCount <= 0) return 0.0;
    return (min(incidentCount, 20) / 20.0).toDouble();
  }

  /// Proximity: farther from help = higher risk. 0m = 0 risk, 5km+ = 1.
  double _pillarProximity(double distanceToHelpMeters) {
    const double maxMeters = 5000;
    if (distanceToHelpMeters <= 0) return 0.0;
    return (min(distanceToHelpMeters, maxMeters) / maxMeters).toDouble();
  }
}

/// Result of async score fetch: either [result] or [error].
class SafetyScoreFetchResult {
  final LiveSafetyScoreResult? result;
  final String? error;
  final String? dataSource;

  const SafetyScoreFetchResult({this.result, this.error, this.dataSource});

  bool get isOk => result != null && error == null;
}

/// Fetches data and computes the live safety score for Sri Lanka.
/// Score factors: population density, closest distance to police station, time of day, past incidents (Sri Lanka data only).
class SafetyScoreInputsProvider {
  final LiveSafetyScoreService _calculator = LiveSafetyScoreService();

  /// Fetches pillar data and computes score. Optimized for Sri Lanka only.
  Future<SafetyScoreFetchResult> getScoreAt({
    required SafetyPosition position,
    DateTime? dateTime,
  }) async {
    final now = dateTime ?? DateTime.now();
    final lat = position.latitude;
    final lng = position.longitude;

    // Outside Sri Lanka: use defaults (e.g. for testing) or still compute with Sri Lanka logic.
    final inSriLanka = SriLankaConfig.isInSriLanka(lat, lng);

    // Run external APIs in parallel (sunrise, help distance, POI density).
    final results = await Future.wait([
      SunriseSunsetApi.getSunriseSunset(lat: lat, lng: lng, date: now),
      OverpassApi.getNearestPoliceOrHospital(lat: lat, lng: lng, radiusMeters: 10000),
      OverpassApi.getPoiDensity(lat: lat, lng: lng, radiusMeters: 500),
      GooglePlacesApi.getPlaceDensity(lat: lat, lng: lng, radiusMeters: 500),
      OverpassApi.getRoadContext(lat: lat, lng: lng, radiusMeters: 250),
      OverpassApi.getNearestEmbassy(lat: lat, lng: lng, radiusMeters: 5000),
    ]);

    final sunriseResult = results[0] as SunriseSunsetResult;
    final helpResult = results[1] as NearestHelpResult;
    final poiResult = results[2] as PoiDensityResult;
    final placesResult = results[3] as PlacesDensityResult;
    final roadContext = results[4] as RoadContextResult;
    final embassyResult = results[5] as NearestEmbassyResult;

    // 1) Time of day: sunrise-sunset API.
    double? timeLightOverride;
    if (sunriseResult.isOk) {
      timeLightOverride = sunriseResult.darknessRisk(now.toUtc());
    }

    // 2) Population density: Sri Lanka district density + activity density (Places/POI).
    double populationDensity = 0.5;
    final double? placesDensity = placesResult.isOk
        ? (placesResult.count / placesResult.areaKm2)
        : null;
    final double? placesScore = placesDensity != null
        ? (placesDensity / 40.0).clamp(0.0, 1.0)
        : null;
    if (inSriLanka) {
      final districtDensity = SriLankaSafetyData.getPopulationDensityAt(lat, lng);
      final poiDensity = poiResult.isOk ? (poiResult.count / 25.0).clamp(0.0, 1.0) : 0.5;
      final activityScore = placesScore ?? poiDensity;
      populationDensity = (districtDensity * 0.55 + activityScore * 0.45).clamp(0.0, 1.0);
    } else if (placesScore != null) {
      populationDensity = placesScore.clamp(0.0, 1.0);
    } else if (poiResult.isOk) {
      populationDensity = (poiResult.count / 25.0).clamp(0.0, 1.0);
    }

    // 3) Closest distance to police or hospital (Overpass).
    double distanceToHelp = 2500.0;
    if (helpResult.isOk) {
      distanceToHelp = helpResult.distanceMeters;
    }

    // 4) Past incidents: Sri Lanka data only (district-level from Sri Lankan records).
    double? incidentRiskOverride;
    if (inSriLanka) {
      incidentRiskOverride = SriLankaSafetyData.getIncidentRiskAt(lat, lng);
    }

    // 5) Venue activity proxy: nearby Places count (fallback to POIs).
    final venueCount = placesResult.isOk
        ? placesResult.count
        : (poiResult.isOk ? poiResult.count : 0);

    final sources = <String>[];
    if (sunriseResult.isOk) sources.add('time of day');
    if (helpResult.isOk) {
      sources.add('help (${helpResult.type})');
    }
    if (placesResult.isOk) {
      sources.add('Places density');
    } else if (poiResult.isOk) {
      sources.add('POI density');
    }
    if (roadContext.isOk) sources.add('road context');
    if (embassyResult.isOk) sources.add('embassy proximity');
    if (inSriLanka) sources.add('Sri Lanka incidents');

    final inputs = SafetyScoreInputs(
      dateTime: now,
      position: position,
      crowdDensity: populationDensity,
      nearbyVenueCount: venueCount,
      isSideLane: roadContext.isSideLane,
      isWellLit: roadContext.isWellLit,
      isNearEmbassy: embassyResult.isOk && embassyResult.distanceMeters <= 1000,
      incidentCount: 0,
      distanceToHelpMeters: distanceToHelp,
      timeLightRiskOverride: timeLightOverride,
      incidentRiskOverride: incidentRiskOverride,
    );

    final result = _calculator.calculate(inputs);
    return SafetyScoreFetchResult(
      result: result,
      dataSource: sources.isEmpty ? null : sources.join(', '),
    );
  }
}

class _SriLankaAreaTuning {
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;
  final int priority;
  final double crowdFloor;
  final double baseBonusDay;
  final double baseBonusNight;
  final double crowdBonusBoost;
  final double timeRefundBoost;
  final double nightIsolationPenalty;

  const _SriLankaAreaTuning({
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.priority,
    required this.crowdFloor,
    required this.baseBonusDay,
    required this.baseBonusNight,
    required this.crowdBonusBoost,
    required this.timeRefundBoost,
    required this.nightIsolationPenalty,
  });
}

_SriLankaAreaTuning? _findSriLankaTuning(SafetyPosition position) {
  _SriLankaAreaTuning? selected;
  double minDist = double.infinity;
  for (final area in LiveSafetyScoreService._slTunings) {
    final d = _haversineMeters(position.latitude, position.longitude, area.lat, area.lng);
    if (d <= area.radiusMeters) {
      if (selected == null || area.priority > selected.priority ||
          (area.priority == selected.priority && d < minDist)) {
        minDist = d;
        selected = area;
      }
    }
  }
  return selected;
}

double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _rad(double deg) => deg * pi / 180;
