/// Central configuration for external safety APIs.
///
/// **No API keys required** for:
/// - [Sunrise-Sunset](https://api.sunrise-sunset.org) (time & light)
/// - [Overpass / OpenStreetMap](https://overpass-api.de) (police, hospital, POI density)
/// - [data.police.uk](https://data.police.uk) (crime in UK only)
///
/// **Optional:** Set [crimeometerApiKey] for US/worldwide crime data (see [setCrimeometerApiKey]).
class SafetyApiConfig {
  SafetyApiConfig._();

  /// Crimeometer API key (optional). When set, enables US/worldwide crime data.
  /// Get a key at https://www.crimeometer.com/ (Crime Data API).
  static String? get crimeometerApiKey => _crimeometerApiKey;
  static String? _crimeometerApiKey;

  /// Set the Crimeometer API key (e.g. at app startup from env or user settings).
  /// Example: `SafetyApiConfig.setCrimeometerApiKey(Platform.environment['CRIMEOMETER_API_KEY']);`
  static void setCrimeometerApiKey(String? key) {
    _crimeometerApiKey = key?.trim().isEmpty == true ? null : key;
  }

  /// Timeout for each external API call (seconds).
  static const int apiTimeoutSeconds = 12;

  /// UK bounding box for data.police.uk (England, Wales, Northern Ireland).
  static bool isInUk(double lat, double lon) {
    return lat >= 49.8 && lat <= 60.8 && lon >= -8.6 && lon <= 1.8;
  }
}
