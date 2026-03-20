import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';

import '../services/native_monitor_service.dart';

class DetectorPage extends StatefulWidget {
  const DetectorPage({super.key});

  @override
  State<DetectorPage> createState() => _DetectorPageState();
}

class _DetectorPageState extends State<DetectorPage>
    with WidgetsBindingObserver {
  static const double _threshold = 0.9;
  static const int _maxGraphPoints = 48;
  static const Duration _resumeRestoreCooldown = Duration(seconds: 4);

  final NativeMonitorService _monitorService = NativeMonitorService();
  StreamSubscription<NativeMonitorStatus>? _statusSub;
  final List<double> _probHistory = <double>[];

  bool running = false;
  bool danger = false;
  bool degraded = false;
  bool stuck = false;
  bool needsForegroundRestore = false;
  double prob = 0.0;
  int hits90In4s = 0;
  int hits95In2s = 0;
  int hits100In1s = 0;
  bool _restoreInFlight = false;
  bool _featureEnabled = false;
  DateTime? _lastAutoRestoreAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _statusSub = _monitorService.statusStream.listen(_applyStatus);
    unawaited(_loadFeatureState());
    unawaited(_refreshStatus());
    unawaited(_handlePendingRestoreRequest());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleResume());
    }
  }

  Future<void> _handleResume() async {
    await _loadFeatureState();
    await _refreshStatus();
    await _handlePendingRestoreRequest();
    await _attemptForegroundRecoveryOnResume();
  }

  Future<void> _loadFeatureState() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('active_microphone_listening') ?? false;
    if (!mounted) return;
    setState(() => _featureEnabled = enabled);
  }

  Future<bool> _ensureFeatureEnabled({bool showDisabledDialog = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('active_microphone_listening') ?? false;
    if (mounted && _featureEnabled != enabled) {
      setState(() => _featureEnabled = enabled);
    }
    if (enabled) return true;
    if (showDisabledDialog && mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.border.withOpacity(0.7)),
            ),
            title: const Text(
              'Feature Turned Off',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'Active Microphone Listening is turned off in Settings. Enable it there manually before using the detector controls.',
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: AppColors.primarySky),
                ),
              ),
            ],
          );
        },
      );
    }
    return false;
  }

  Future<void> _handlePendingRestoreRequest() async {
    if (!await _ensureFeatureEnabled(showDisabledDialog: false)) return;
    final shouldRestore = await _monitorService.consumeRestoreRequest();
    if (!shouldRestore) return;
    await _runRestoreAttempt();
  }

  Future<void> _refreshStatus() async {
    final status = await _monitorService.getStatus();
    if (!mounted) return;
    _applyStatus(status);
  }

  void _applyStatus(NativeMonitorStatus status) {
    if (!mounted) return;
    setState(() {
      running = status.running;
      danger = status.danger;
      degraded = status.degraded;
      stuck = status.stuck;
      needsForegroundRestore = status.needsForegroundRestore;
      prob = status.probability;
      hits90In4s = status.hits90In4s;
      hits95In2s = status.hits95In2s;
      hits100In1s = status.hits100In1s;

      if (status.running && !status.degraded) {
        _probHistory.add(status.probability);
        if (_probHistory.length > _maxGraphPoints) {
          _probHistory.removeAt(0);
        }
      } else {
        _probHistory.clear();
      }
    });
  }

  Future<void> _start() async {
    if (!await _ensureFeatureEnabled()) return;
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    final notificationPermission = await Permission.notification.request();
    if (!notificationPermission.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification permission denied')),
      );
      return;
    }

    await _monitorService.startMonitoring();
    await _refreshStatus();
  }

  Future<void> _stop() async {
    if (!await _ensureFeatureEnabled()) return;
    await _monitorService.stopMonitoring();
    await _refreshStatus();
  }

  Future<void> _restore() async {
    if (!await _ensureFeatureEnabled()) return;
    await _runRestoreAttempt();
  }

  Future<void> _runRestoreAttempt() async {
    if (_restoreInFlight) return;
    _restoreInFlight = true;
    try {
      await _monitorService.restoreListening();
      await _refreshStatus();
    } finally {
      _restoreInFlight = false;
    }
  }

  Future<void> _attemptForegroundRecoveryOnResume() async {
    if (!await _ensureFeatureEnabled(showDisabledDialog: false)) return;
    if (!mounted || !running || danger) return;
    if (!(stuck || degraded)) return;
    if (_restoreInFlight) return;

    final now = DateTime.now();
    final lastAttempt = _lastAutoRestoreAt;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < _resumeRestoreCooldown) {
      return;
    }

    _lastAutoRestoreAt = now;
    await _runRestoreAttempt();
  }

  String get _stateLabel {
    if (danger) return 'Danger detected';
    if (stuck) return needsForegroundRestore ? 'Needs app restore' : 'Restore from app';
    if (degraded) return 'Recovering microphone';
    if (running) return 'Actively listening';
    return 'Idle';
  }

  String get _stateMessage {
    if (danger) {
      return 'High-confidence scream pattern detected. Monitoring hands off to the emergency flow.';
    }
    if (stuck) {
      return needsForegroundRestore
          ? 'Audio access was interrupted. Open USafe from the notification to restore listening.'
          : 'Audio access was interrupted. Restore listening from inside the app.';
    }
    if (degraded) {
      return 'The service is trying to recover microphone capture in the background.';
    }
    if (running) {
      return 'Background monitoring is active and streaming live probability updates.';
    }
    return 'Start listening to enable on-device scream detection and live monitoring.';
  }

  Color get _stateAccent {
    if (danger) return AppColors.alert;
    if (stuck) return AppColors.alertDark;
    if (degraded) return const Color(0xFFF59E0B);
    if (running) return AppColors.safetyTeal;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final probabilityPercent = (prob * 100).clamp(0, 100).toStringAsFixed(1);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Detector',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(probabilityPercent),
              const SizedBox(height: 20),
              if (!_featureEnabled) ...[
                _buildFeatureDisabledCard(),
                const SizedBox(height: 20),
              ],
              _buildMetricsRow(probabilityPercent),
              const SizedBox(height: 20),
              _buildChartPanel(),
              const SizedBox(height: 20),
              _buildRulesPanel(),
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(String probabilityPercent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _stateAccent.withOpacity(0.28),
            AppColors.surface.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _stateAccent.withOpacity(0.35), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: _stateAccent.withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.multitrack_audio_rounded, color: _stateAccent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stateLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stateMessage,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                probabilityPercent,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 4),
                child: Text(
                  '% probability',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: prob.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(_stateAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(String probabilityPercent) {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            label: 'Monitor',
            value: running ? 'ON' : 'OFF',
            icon: Icons.mic_rounded,
            accent: running ? AppColors.safetyTeal : AppColors.textDisabled,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(
            label: 'Signal',
            value: probabilityPercent,
            icon: Icons.show_chart_rounded,
            accent: _stateAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureDisabledCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.alert.withOpacity(0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.alert.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.alert.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_off_rounded,
              color: AppColors.alert,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detector Controls Locked',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Active Microphone Listening is off in Settings, so detector actions are unavailable until you enable it manually.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withOpacity(0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartPanel() {
    return _panel(
      title: 'Live Probability',
      subtitle: 'Recent inference values from the on-device audio model',
      child: Container(
        width: double.infinity,
        height: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.panelBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withOpacity(0.6)),
        ),
        child: CustomPaint(
          painter: _ProbabilityGraphPainter(
            values: List<double>.from(_probHistory),
            threshold: _threshold,
            isDanger: danger,
          ),
        ),
      ),
    );
  }

  Widget _buildRulesPanel() {
    return _panel(
      title: 'Danger Rules',
      subtitle: 'Threshold combinations that promote the session into emergency mode',
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.panelBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withOpacity(0.6)),
        ),
        child: Column(
          children: [
            _RuleRow(
              label: '4 hits >= 0.90 in 4 seconds',
              current: hits90In4s,
              target: 4,
            ),
            _divider(),
            _RuleRow(
              label: '2 hits >= 0.95 in 2 seconds',
              current: hits95In2s,
              target: 2,
            ),
            _divider(),
            _RuleRow(
              label: '1 hit = 1.00 in 1 second',
              current: hits100In1s,
              target: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceElevated.withOpacity(0.5),
            AppColors.surface.withOpacity(0.42),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border.withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withOpacity(0.06),
    );
  }

  Widget _buildActionButtons() {
    final canRestore = running && stuck;
    final canStop = running;
    final primaryLabel = canRestore ? 'Restore Listening' : 'Start Listening';
    final primaryAction = running ? (stuck ? _restore : null) : _start;
    final stopAction = canStop ? _stop : null;

    final buttons = Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _featureEnabled ? primaryAction : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _stateAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _stateAccent.withOpacity(0.45),
              disabledForegroundColor: Colors.white54,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              primaryLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: _featureEnabled ? stopAction : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white54,
              side: BorderSide(color: AppColors.border.withOpacity(0.9)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              'Stop',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );

    if (_featureEnabled) {
      return buttons;
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
            child: Opacity(
              opacity: 0.55,
              child: buttons,
            ),
          ),
        ),
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _showFeatureDisabledDialog,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _showFeatureDisabledDialog,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showFeatureDisabledDialog() async {
    await _ensureFeatureEnabled();
  }
}

class _RuleRow extends StatelessWidget {
  final String label;
  final int current;
  final int target;

  const _RuleRow({
    required this.label,
    required this.current,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final met = current >= target;
    final accent = met ? AppColors.alert : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withOpacity(0.28)),
            ),
            child: Text(
              '$current / $target',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProbabilityGraphPainter extends CustomPainter {
  final List<double> values;
  final double threshold;
  final bool isDanger;
  static const double _visualFloorInput = 0.4;
  static const double _visualFloorOutput = 0.1;

  _ProbabilityGraphPainter({
    required this.values,
    required this.threshold,
    required this.isDanger,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = AppColors.panelBackground
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      backgroundPaint,
    );

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final thresholdY =
        size.height * (1 - _mapDisplayValue(threshold.clamp(0.0, 1.0)));
    final thresholdPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(0, thresholdY),
      Offset(size.width, thresholdY),
      thresholdPaint,
    );

    if (values.isEmpty) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'No live audio data yet',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
      return;
    }

    final lineColor = isDanger ? AppColors.alert : AppColors.safetyTeal;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = lineColor.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final dx = values.length == 1 ? size.width : size.width / (values.length - 1);
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      points.add(
        Offset(
          dx * i,
          size.height * (1 - _mapDisplayValue(values[i].clamp(0.0, 1.0))),
        ),
      );
    }

    final path = _buildSmoothPath(points);
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
    canvas.drawCircle(
      points.last,
      4,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill,
    );
  }

  Path _buildSmoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return path;
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final controlX = (current.dx + next.dx) / 2;
      path.cubicTo(controlX, current.dy, controlX, next.dy, next.dx, next.dy);
    }
    return path;
  }

  double _mapDisplayValue(double value) {
    if (value <= 0.0) return 0.0;
    if (value >= 1.0) return 1.0;
    if (value <= _visualFloorInput) {
      return (value / _visualFloorInput) * _visualFloorOutput;
    }
    final normalized = (value - _visualFloorInput) / (1.0 - _visualFloorInput);
    return _visualFloorOutput + normalized * (1.0 - _visualFloorOutput);
  }

  @override
  bool shouldRepaint(covariant _ProbabilityGraphPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.threshold != threshold ||
        oldDelegate.isDanger != isDanger;
  }
}
