class AudioAnalysisService {
  static final AudioAnalysisService _instance = AudioAnalysisService._internal();
  factory AudioAnalysisService() => _instance;
  AudioAnalysisService._internal();

  bool get isReady => false;
  String? get lastError => 'Audio analysis is not available on web.';

  Function(String event, double confidence)? onDistressDetected;

  Future<void> initialize() async {}

  Future<bool> startListening() async {
    return false;
  }

  Future<void> stopListening() async {}
}
