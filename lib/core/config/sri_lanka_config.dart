/// Sri Lanka–specific configuration. This app is optimized for Sri Lanka only.
class SriLankaConfig {
  SriLankaConfig._();

  /// Country code for Sri Lanka.
  static const String countryCode = 'LK';

  /// Bounding box: Sri Lanka (approximate). Lat 5.9–9.8, Lon 79.5–82.0.
  static const double latMin = 5.9;
  static const double latMax = 9.8;
  static const double lonMin = 79.5;
  static const double lonMax = 82.0;

  /// Whether the given coordinates are within Sri Lanka.
  static bool isInSriLanka(double lat, double lon) {
    return lat >= latMin && lat <= latMax && lon >= lonMin && lon <= lonMax;
  }

  /// Default center (Colombo) for map initial position when in Sri Lanka.
  static const double defaultLat = 6.9271;
  static const double defaultLon = 79.8612;
}
