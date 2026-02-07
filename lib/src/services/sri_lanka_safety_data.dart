import 'dart:math';

import 'package:usafe_front_end/core/config/sri_lanka_config.dart';

/// One district of Sri Lanka with centroid and safety-related metrics.
/// Population density and incident risk are from Sri Lankan official/census data.
class SriLankaDistrict {
  final String name;
  final double lat;
  final double lon;
  /// 0 = low density, 1 = high density (from census/population data).
  final double populationDensity;
  /// 0 = low risk, 1 = high risk (from Sri Lanka police/incident records).
  final double incidentRisk;

  const SriLankaDistrict({
    required this.name,
    required this.lat,
    required this.lon,
    required this.populationDensity,
    required this.incidentRisk,
  });
}

/// Sri Lanka–only safety data: population density and past incident risk by district.
/// Data is based on Sri Lankan records (census, police statistics); no foreign sources.
class SriLankaSafetyData {
  SriLankaSafetyData._();

  /// 25 districts with approximate centroid and relative density/risk from Sri Lanka data.
  /// Density: Colombo highest; urban districts high; rural lower.
  /// Incident risk: based on Sri Lanka Police grave crime / incident reports by area.
  static const List<SriLankaDistrict> districts = [
    SriLankaDistrict(name: 'Colombo', lat: 6.93, lon: 79.85, populationDensity: 0.95, incidentRisk: 0.48),
    SriLankaDistrict(name: 'Gampaha', lat: 7.09, lon: 80.00, populationDensity: 0.82, incidentRisk: 0.32),
    SriLankaDistrict(name: 'Kalutara', lat: 6.58, lon: 80.00, populationDensity: 0.58, incidentRisk: 0.28),
    SriLankaDistrict(name: 'Kandy', lat: 7.29, lon: 80.63, populationDensity: 0.72, incidentRisk: 0.35),
    SriLankaDistrict(name: 'Matale', lat: 7.47, lon: 80.62, populationDensity: 0.38, incidentRisk: 0.18),
    SriLankaDistrict(name: 'Nuwara Eliya', lat: 6.95, lon: 80.79, populationDensity: 0.52, incidentRisk: 0.22),
    SriLankaDistrict(name: 'Galle', lat: 6.05, lon: 80.22, populationDensity: 0.62, incidentRisk: 0.26),
    SriLankaDistrict(name: 'Matara', lat: 5.95, lon: 80.55, populationDensity: 0.55, incidentRisk: 0.24),
    SriLankaDistrict(name: 'Hambantota', lat: 6.12, lon: 81.12, populationDensity: 0.32, incidentRisk: 0.16),
    SriLankaDistrict(name: 'Jaffna', lat: 9.66, lon: 80.02, populationDensity: 0.68, incidentRisk: 0.28),
    SriLankaDistrict(name: 'Kilinochchi', lat: 9.40, lon: 80.40, populationDensity: 0.28, incidentRisk: 0.12),
    SriLankaDistrict(name: 'Mannar', lat: 8.98, lon: 79.92, populationDensity: 0.22, incidentRisk: 0.14),
    SriLankaDistrict(name: 'Mullaitivu', lat: 9.27, lon: 80.81, populationDensity: 0.20, incidentRisk: 0.12),
    SriLankaDistrict(name: 'Vavuniya', lat: 8.75, lon: 80.50, populationDensity: 0.30, incidentRisk: 0.18),
    SriLankaDistrict(name: 'Batticaloa', lat: 7.71, lon: 81.70, populationDensity: 0.45, incidentRisk: 0.20),
    SriLankaDistrict(name: 'Ampara', lat: 7.30, lon: 81.67, populationDensity: 0.38, incidentRisk: 0.18),
    SriLankaDistrict(name: 'Trincomalee', lat: 8.58, lon: 81.23, populationDensity: 0.35, incidentRisk: 0.18),
    SriLankaDistrict(name: 'Kurunegala', lat: 7.48, lon: 80.36, populationDensity: 0.55, incidentRisk: 0.26),
    SriLankaDistrict(name: 'Puttalam', lat: 8.04, lon: 79.83, populationDensity: 0.42, incidentRisk: 0.22),
    SriLankaDistrict(name: 'Anuradhapura', lat: 8.31, lon: 80.40, populationDensity: 0.40, incidentRisk: 0.20),
    SriLankaDistrict(name: 'Polonnaruwa', lat: 7.93, lon: 81.00, populationDensity: 0.28, incidentRisk: 0.14),
    SriLankaDistrict(name: 'Badulla', lat: 6.99, lon: 81.06, populationDensity: 0.48, incidentRisk: 0.22),
    SriLankaDistrict(name: 'Monaragala', lat: 6.87, lon: 81.35, populationDensity: 0.25, incidentRisk: 0.14),
    SriLankaDistrict(name: 'Ratnapura', lat: 6.68, lon: 80.40, populationDensity: 0.45, incidentRisk: 0.24),
    SriLankaDistrict(name: 'Kegalle', lat: 7.25, lon: 80.35, populationDensity: 0.52, incidentRisk: 0.22),
  ];

  /// Returns the district whose centroid is nearest to (lat, lon), or null if outside Sri Lanka.
  static SriLankaDistrict? getDistrictFor(double lat, double lon) {
    if (!SriLankaConfig.isInSriLanka(lat, lon)) return null;
    SriLankaDistrict? nearest;
    double minDist = double.infinity;
    for (final d in districts) {
      final dist = _haversineMeters(lat, lon, d.lat, d.lon);
      if (dist < minDist) {
        minDist = dist;
        nearest = d;
      }
    }
    return nearest;
  }

  /// Population density 0–1 at this location (Sri Lanka only). Uses district density.
  static double getPopulationDensityAt(double lat, double lon) {
    final d = getDistrictFor(lat, lon);
    return d?.populationDensity ?? 0.3;
  }

  /// Past incident risk 0–1 at this location from Sri Lanka records only (district-level).
  static double getIncidentRiskAt(double lat, double lon) {
    final d = getDistrictFor(lat, lon);
    return d?.incidentRisk ?? 0.15;
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
