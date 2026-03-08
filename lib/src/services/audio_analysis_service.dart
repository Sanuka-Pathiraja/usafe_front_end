import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:record/record.dart';
import 'package:audio_session/audio_session.dart';

class AudioAnalysisService {
  static final AudioAnalysisService _instance = AudioAnalysisService._internal();
  factory AudioAnalysisService() => _instance;
  AudioAnalysisService._internal();

  Interpreter? _interpreter;
  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _audioSubscription;

  static const int sampleRate = 16000;
  static const int requiredSamples = 15600;

  final List<double> _audioBuffer = [];
  bool _isRecording = false;
  List<String> _labels = [];
  String? _lastError;
  int _consecutiveAudioErrors = 0;
  static const int _maxConsecutiveAudioErrors = 3;

  bool get isReady => _interpreter != null;
  String? get lastError => _lastError;

  Function(String event, double confidence)? onDistressDetected;

  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/yamnet.tflite');
      final csvData =
          await rootBundle.loadString('assets/models/yamnet_class_map.csv');
      _parseLabels(csvData);
    } catch (e) {
      // Keep silent to avoid crashing; feature will stay inactive.
    }
  }

  void _parseLabels(String csvData) {
    _labels = [];
    final lines = csvData.split('\n');
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final firstComma = line.indexOf(',');
      final secondComma = line.indexOf(',', firstComma + 1);
      if (secondComma == -1) continue;
      var displayName = line.substring(secondComma + 1);
      if (displayName.startsWith('"') && displayName.endsWith('"')) {
        displayName = displayName.substring(1, displayName.length - 1);
      }
      _labels.add(displayName);
    }
  }

  Future<bool> startListening() async {
    if (_isRecording) return true;
    if (!isReady) {
      _lastError = 'Audio model not ready.';
      return false;
    }

    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());

    _audioRecorder = AudioRecorder();
    if (!await _audioRecorder!.hasPermission()) {
      _lastError = 'Microphone permission denied.';
      await _audioRecorder?.dispose();
      _audioRecorder = null;
      return false;
    }

    final stream = await _audioRecorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );

    _isRecording = true;
    _consecutiveAudioErrors = 0;
    _audioBuffer.clear();
    _audioSubscription = stream.listen(
      _processAudioData,
      onError: (Object error, StackTrace stackTrace) async {
        _consecutiveAudioErrors++;
        _lastError = 'Audio stream error: $error';
        if (_consecutiveAudioErrors >= _maxConsecutiveAudioErrors) {
          await stopListening();
        }
      },
      cancelOnError: true,
    );
    _lastError = null;
    return true;
  }

  void _processAudioData(Uint8List data) {
    final int16List = Int16List.view(data.buffer);
    for (final sample in int16List) {
      _audioBuffer.add(sample / 32768.0);
    }

    if (_audioBuffer.length >= requiredSamples) {
      final inputChunk = _audioBuffer.sublist(0, requiredSamples);
      _audioBuffer.removeRange(0, requiredSamples);
      _runInference(inputChunk);
    }
  }

  void _runInference(List<double> inputSignal) {
    if (_interpreter == null) return;

    final input = [inputSignal];
    final output = List.filled(1 * 521, 0.0).reshape([1, 521]);
    _interpreter!.run(input, output);

    final scores = output[0] as List<double>;
    _analyzeResults(scores);
  }

  void _analyzeResults(List<double> scores) {
    if (_labels.isEmpty) return;

    final Map<String, double> results = {};
    for (int i = 0; i < scores.length && i < _labels.length; i++) {
      results[_labels[i]] = scores[i];
    }

    const distressTerms = [
      'Scream',
      'Screaming',
      'Yell',
      'Shout',
      'Crying, sobbing'
    ];

    String? detectedEvent;
    double maxConfidence = 0.0;

    for (final term in distressTerms) {
      results.forEach((label, score) {
        if (label.contains(term) && score > maxConfidence && score > 0.4) {
          maxConfidence = score;
          detectedEvent = label;
        }
      });
    }

    if (detectedEvent != null) {
      onDistressDetected?.call(detectedEvent!, maxConfidence);
    }
  }

  Future<void> stopListening() async {
    _isRecording = false;
    _audioBuffer.clear();
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _audioRecorder?.stop();
    await _audioRecorder?.dispose();
    _audioRecorder = null;
  }
}
