class ToneSOSBridgeService {
  static final ToneSOSBridgeService _instance = ToneSOSBridgeService._internal();
  factory ToneSOSBridgeService() => _instance;
  ToneSOSBridgeService._internal();

  bool get isReady => false;

  Future<void> initialize() async {}

  Future<void> startListening() async {}

  Future<void> stopListening() async {}
}
