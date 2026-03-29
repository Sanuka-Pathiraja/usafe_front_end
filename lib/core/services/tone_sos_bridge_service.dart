import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:record/record.dart';
import 'package:audio_session/audio_session.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

class ToneSOSBridgeService {
  static final ToneSOSBridgeService _instance =
      ToneSOSBridgeService._internal();
  factory ToneSOSBridgeService() => _instance;
  ToneSOSBridgeService._internal();

  Interpreter? _interpreter;
  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _audioSubscription;
  bool _isRecording = false;
  List<double> _audioBuffer = [];
  List<String> _labels = [];
  int _consecutiveAudioErrors = 0;
  static const int _maxConsecutiveAudioErrors = 3;

  bool get isReady => _interpreter != null && _labels.isNotEmpty;

  Future<void> initialize() async {
    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        return;
      }
      try {
        _interpreter = await Interpreter.fromAsset('assets/models/yamnet.tflite');
        final csvData = await rootBundle.loadString('assets/models/yamnet_class_map.csv');
        _parseLabels(csvData);
        print('✅ YAMNet model loaded successfully!');
      } catch (e) {
        print('⚠️ Failed to load YAMNet model: $e');
        print('Audio ML features will be disabled.');
        _interpreter = null;
      }
    } catch (e) {
      print('⚠️ Error during audio service initialization: $e');
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

  Future<void> startListening() async {
    if (_isRecording) return;
    if (!isReady) {
      // Model unavailable: do not start microphone stream.
      return;
    }
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.speech());

      _audioRecorder = AudioRecorder();
      if (!await _audioRecorder!.hasPermission()) {
        return;
      }

      final stream = await _audioRecorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
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
          if (_consecutiveAudioErrors >= _maxConsecutiveAudioErrors) {
            await stopListening();
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      // Fail gracefully, do not crash app
      await stopListening();
    }
  }

  void _processAudioData(Uint8List data) {
    final int16List = Int16List.view(data.buffer);
    for (final sample in int16List) {
      _audioBuffer.add(sample / 32768.0);
    }

    if (_audioBuffer.length >= 15600) {
      final inputChunk = _audioBuffer.sublist(0, 15600);
      _audioBuffer.removeRange(0, 15600);
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

  void _analyzeResults(List<double> scores) async {
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
      await _triggerSOSBackend(detectedEvent!, maxConfidence);
    }
  }

  Future<void> _triggerSOSBackend(String event, double confidence) async {
    try {
      // Use Supabase for JWT
      final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
      if (jwt == null) return;
      await ApiService.sendDistressSignal(event, confidence, jwt);
    } catch (e) {
      // Fail gracefully, do not crash app
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
