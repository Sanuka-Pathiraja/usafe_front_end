import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class MotionAnalysisService {
  static final MotionAnalysisService _instance = MotionAnalysisService._internal();
  factory MotionAnalysisService() => _instance;
  MotionAnalysisService._internal();

  static const Duration _triggerCooldown = Duration(seconds: 8);
  static const int _windowSize = 20;
  static const double _spikeThreshold = 12.0; // m/s^2 above rolling average
  static const double _absoluteThreshold = 25.0; // strong jerk threshold

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final List<double> _magnitudes = [];
  bool _isListening = false;
  DateTime? _lastTriggerAt;

  Function(String event, double confidence)? onMotionDetected;

  bool get isListening => _isListening;

  Future<bool> startListening() async {
    if (_isListening) return true;
    _magnitudes.clear();
    _accelerometerSubscription = accelerometerEvents.listen(_processEvent);
    _isListening = true;
    return true;
  }

  void _processEvent(AccelerometerEvent event) {
    final magnitude = sqrt(
      (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
    );
    _magnitudes.add(magnitude);
    if (_magnitudes.length > _windowSize) {
      _magnitudes.removeAt(0);
    }

    final now = DateTime.now();
    if (_lastTriggerAt != null && now.difference(_lastTriggerAt!) < _triggerCooldown) {
      return;
    }

    if (_magnitudes.length < _windowSize) return;

    final avg = _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;
    final delta = magnitude - avg;

    if (magnitude >= _absoluteThreshold || delta >= _spikeThreshold) {
      _lastTriggerAt = now;
      final confidence = min(1.0, (delta / _spikeThreshold).clamp(0.0, 2.0) / 2.0);
      onMotionDetected?.call('Sudden movement', confidence);
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    _magnitudes.clear();
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }
}
