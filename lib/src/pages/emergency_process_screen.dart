import 'dart:async';
import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'emergency_result_screen.dart';

enum EmergencyStepType { messageAll, callContact, waitBefore119, call119 }

class EmergencyStep {
  final String title;
  final EmergencyStepType type;
  final int? contactIndex;
  final Duration duration;

  const EmergencyStep(
    this.title,
    this.type, {
    this.contactIndex,
    required this.duration,
  });
}

enum StepState { pending, running, done, skipped, failed }

class EmergencyProcessScreen extends StatefulWidget {
  final Future<void> Function()? onMessageAllContacts;
  final Future<bool> Function(int contactIndex)? onCallContact;
  final Future<void> Function()? onCall119;

  const EmergencyProcessScreen({
    super.key,
    this.onMessageAllContacts,
    this.onCallContact,
    this.onCall119,
  });

  @override
  State<EmergencyProcessScreen> createState() => _EmergencyProcessScreenState();
}

class _EmergencyProcessScreenState extends State<EmergencyProcessScreen> {
  final Color bgDark = AppColors.background;
  final Color accentBlue = AppColors.primarySky;
  final Color dangerRed = const Color(0xFFFF3D00);
  final Color tealBtn = const Color(0xFF1DE9B6);

  final List<EmergencyStep> _steps = const [
    EmergencyStep(
      "Messaging all emergency contacts",
      EmergencyStepType.messageAll,
      duration: Duration(minutes: 1),
    ),
    EmergencyStep(
      "Calling Emergency contact 1",
      EmergencyStepType.callContact,
      contactIndex: 1,
      duration: Duration(seconds: 30),
    ),
    EmergencyStep(
      "Calling Emergency contact 2",
      EmergencyStepType.callContact,
      contactIndex: 2,
      duration: Duration(seconds: 30),
    ),
    EmergencyStep(
      "Calling Emergency contact 3",
      EmergencyStepType.callContact,
      contactIndex: 3,
      duration: Duration(seconds: 30),
    ),
    EmergencyStep(
      "Calling Emergency contact 4",
      EmergencyStepType.callContact,
      contactIndex: 4,
      duration: Duration(seconds: 30),
    ),
    EmergencyStep(
      "Calling Emergency contact 5",
      EmergencyStepType.callContact,
      contactIndex: 5,
      duration: Duration(seconds: 30),
    ),
    EmergencyStep(
      "Waiting before contacting Emergency Services",
      EmergencyStepType.waitBefore119,
      duration: Duration(minutes: 1),
    ),
    EmergencyStep(
      "Calling Emergency Services (119)",
      EmergencyStepType.call119,
      duration: Duration(seconds: 10),
    ),
  ];

  late List<StepState> _states;
  int _currentIndex = 0;

  bool _screenClosed = false;
  bool _someoneAnswered = false;
  bool _emergencyServicesCalled = false;

  // step progress
  double _stepProgress = 0.0;
  Duration _stepRemaining = Duration.zero;
  Timer? _stepTimer;

  // flow cancel token
  int _flowId = 0;

  @override
  void initState() {
    super.initState();
    _states = List<StepState>.filled(_steps.length, StepState.pending);
    _startDefaultProcess();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  // ---------- Navigation to Result ----------
  Future<void> _goToResult(EmergencySummary summary) async {
    if (!mounted || _screenClosed) return;
    _screenClosed = true;

    final payload = await Navigator.push<HomeEmergencyBannerPayload>(
      context,
      MaterialPageRoute(builder: (_) => EmergencyResultScreen(summary: summary)),
    );

    if (!mounted) return;
    Navigator.pop(context, payload);
  }

  // ---------- Flow helpers ----------
  void _cancelCurrentFlow() {
    _flowId++;
    _stepTimer?.cancel();
  }

  void _startDefaultProcess() {
    final myFlow = ++_flowId;
    _runDefaultSteps(myFlow);
  }

  Future<void> _runDefaultSteps(int myFlow) async {
    for (int i = 0; i < _steps.length; i++) {
      if (!mounted || myFlow != _flowId) return;

      if (_someoneAnswered && _steps[i].type == EmergencyStepType.callContact) {
        setState(() => _states[i] = StepState.skipped);
        continue;
      }

      setState(() {
        _currentIndex = i;
        _states[i] = StepState.running;
        _stepProgress = 0.0;
        _stepRemaining = _steps[i].duration;
      });

      final step = _steps[i];

      try {
        switch (step.type) {
          case EmergencyStepType.messageAll:
            await _runFixedDurationStep<void>(
              flow: myFlow,
              duration: step.duration,
              action: () async => await _messageAll(),
            );
            break;

          case EmergencyStepType.callContact:
            final answered = await _runFixedDurationStep<bool>(
              flow: myFlow,
              duration: step.duration,
              action: () async => await _callContact(step.contactIndex!),
            );
            if (myFlow != _flowId) return;

            if (answered) {
              _someoneAnswered = true;
              _skipRemainingContactCalls(fromIndex: i + 1);
            }
            break;

          case EmergencyStepType.waitBefore119:
            await _runFixedDurationStep<void>(
              flow: myFlow,
              duration: step.duration,
              action: () async {},
            );
            break;

          case EmergencyStepType.call119:
            await _runFixedDurationStep<void>(
              flow: myFlow,
              duration: step.duration,
              action: () async => await _call119(),
            );
            _emergencyServicesCalled = true;
            break;
        }

        if (!mounted || myFlow != _flowId) return;
        setState(() => _states[i] = StepState.done);
      } catch (_) {
        if (!mounted || myFlow != _flowId) return;

        setState(() => _states[i] = StepState.failed);

        await _goToResult(EmergencySummary(
          outcome: EmergencyOutcome.failed,
          someoneAnswered: _someoneAnswered,
          emergencyServicesCalled: _emergencyServicesCalled,
          failedStepIndex: i,
          failedStepTitle: _steps[i].title,
        ));
        return;
      }
    }

    if (!mounted || myFlow != _flowId) return;

    await _goToResult(EmergencySummary(
      outcome: EmergencyOutcome.completed,
      someoneAnswered: _someoneAnswered,
      emergencyServicesCalled: _emergencyServicesCalled,
    ));
  }

  void _skipRemainingContactCalls({required int fromIndex}) {
    for (int k = fromIndex; k < _steps.length; k++) {
      if (_steps[k].type == EmergencyStepType.callContact &&
          _states[k] == StepState.pending) {
        _states[k] = StepState.skipped;
      }
    }
    if (mounted) setState(() {});
  }

  Future<T> _runFixedDurationStep<T>({
    required int flow,
    required Duration duration,
    required Future<T> Function() action,
  }) async {
    _stepTimer?.cancel();
    _stepRemaining = duration;

    const tick = Duration(milliseconds: 200);
    final stopwatch = Stopwatch()..start();

    if (mounted) {
      setState(() {
        _stepProgress = 0.0;
        _stepRemaining = duration;
      });
    }

    _stepTimer = Timer.periodic(tick, (_) {
      if (!mounted || flow != _flowId) return;

      final elapsed = stopwatch.elapsed;
      final remaining = duration - elapsed;
      _stepRemaining = remaining.isNegative ? Duration.zero : remaining;

      final p = elapsed.inMilliseconds / duration.inMilliseconds;
      setState(() => _stepProgress = p.clamp(0.0, 1.0));
    });

    late T result;
    Object? err;
    try {
      result = await action();
    } catch (e) {
      err = e;
    }

    if (!mounted || flow != _flowId) {
      _stepTimer?.cancel();
      throw StateError("Flow cancelled");
    }

    final elapsed = stopwatch.elapsed;
    if (elapsed < duration && flow == _flowId) {
      await Future.delayed(duration - elapsed);
    }

    if (!mounted || flow != _flowId) {
      _stepTimer?.cancel();
      throw StateError("Flow cancelled");
    }

    _stepTimer?.cancel();
    if (mounted) {
      setState(() {
        _stepProgress = 1.0;
        _stepRemaining = Duration.zero;
      });
    }

    if (err != null) throw err;
    return result;
  }

  // ---------- Manual override buttons ----------
  Future<void> _stopProcess() async {
    _cancelCurrentFlow();
    await _goToResult(EmergencySummary(
      outcome: EmergencyOutcome.cancelled,
      someoneAnswered: _someoneAnswered,
      emergencyServicesCalled: _emergencyServicesCalled,
    ));
  }

  Future<void> _call119NowTakeOver() async {
    _cancelCurrentFlow();
    final myFlow = ++_flowId;

    final idx119 = _steps.indexWhere((s) => s.type == EmergencyStepType.call119);

    setState(() {
      for (int i = 0; i < _steps.length; i++) {
        if (i < idx119) {
          _states[i] =
              (_states[i] == StepState.done) ? StepState.done : StepState.skipped;
        } else if (i == idx119) {
          _states[i] = StepState.running;
          _currentIndex = i;
          _stepProgress = 0.0;
          _stepRemaining = _steps[i].duration;
        } else {
          _states[i] = StepState.pending;
        }
      }
    });

    try {
      await _runFixedDurationStep<void>(
        flow: myFlow,
        duration: _steps[idx119].duration,
        action: () async => await _call119(),
      );
      _emergencyServicesCalled = true;

      if (!mounted || myFlow != _flowId) return;
      setState(() => _states[idx119] = StepState.done);

      await _goToResult(EmergencySummary(
        outcome: EmergencyOutcome.completed,
        someoneAnswered: _someoneAnswered,
        emergencyServicesCalled: _emergencyServicesCalled,
      ));
    } catch (_) {
      if (!mounted || myFlow != _flowId) return;
      setState(() => _states[idx119] = StepState.failed);

      await _goToResult(EmergencySummary(
        outcome: EmergencyOutcome.failed,
        someoneAnswered: _someoneAnswered,
        emergencyServicesCalled: _emergencyServicesCalled,
        failedStepIndex: idx119,
        failedStepTitle: _steps[idx119].title,
      ));
    }
  }

  Future<void> _notifyAllInstantlyTakeOver() async {
    _cancelCurrentFlow();
    final myFlow = ++_flowId;
    _someoneAnswered = false;

    final msgIdx =
        _steps.indexWhere((s) => s.type == EmergencyStepType.messageAll);
    final idxWait =
        _steps.indexWhere((s) => s.type == EmergencyStepType.waitBefore119);
    final idx119 = _steps.indexWhere((s) => s.type == EmergencyStepType.call119);

    final callIdxs = <int>[];
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i].type == EmergencyStepType.callContact) callIdxs.add(i);
    }

    setState(() {
      for (int i = 0; i < _steps.length; i++) {
        if (i == idxWait) {
          _states[i] = StepState.skipped;
        } else if (_states[i] != StepState.done) {
          _states[i] = StepState.pending;
        }
      }
    });

    // Message (fast but visible)
    setState(() {
      _currentIndex = msgIdx;
      _states[msgIdx] = StepState.running;
      _stepProgress = 0.0;
      _stepRemaining = const Duration(seconds: 8);
    });

    try {
      await _runFixedDurationStep<void>(
        flow: myFlow,
        duration: const Duration(seconds: 8),
        action: () async => await _messageAll(),
      );
      if (!mounted || myFlow != _flowId) return;
      setState(() => _states[msgIdx] = StepState.done);
    } catch (_) {
      if (!mounted || myFlow != _flowId) return;
      setState(() => _states[msgIdx] = StepState.failed);

      await _goToResult(EmergencySummary(
        outcome: EmergencyOutcome.failed,
        someoneAnswered: _someoneAnswered,
        emergencyServicesCalled: _emergencyServicesCalled,
        failedStepIndex: msgIdx,
        failedStepTitle: _steps[msgIdx].title,
      ));
      return;
    }

    // Calls (fast but visible)
    for (final idx in callIdxs) {
      if (!mounted || myFlow != _flowId) return;

      if (_someoneAnswered) {
        setState(() => _states[idx] = StepState.skipped);
        continue;
      }

      setState(() {
        _currentIndex = idx;
        _states[idx] = StepState.running;
        _stepProgress = 0.0;
        _stepRemaining = const Duration(seconds: 6);
      });

      try {
        final answered = await _runFixedDurationStep<bool>(
          flow: myFlow,
          duration: const Duration(seconds: 6),
          action: () async => await _callContact(_steps[idx].contactIndex!),
        );
        if (!mounted || myFlow != _flowId) return;

        setState(() => _states[idx] = StepState.done);

        if (answered) {
          _someoneAnswered = true;
          for (final later in callIdxs) {
            if (later > idx && _states[later] == StepState.pending) {
              _states[later] = StepState.skipped;
            }
          }
          if (mounted) setState(() {});
        }
      } catch (_) {
        if (!mounted || myFlow != _flowId) return;
        setState(() => _states[idx] = StepState.failed);
      }
    }

    // Call 119 (fast but visible)
    setState(() {
      _currentIndex = idx119;
      _states[idx119] = StepState.running;
      _stepProgress = 0.0;
      _stepRemaining = const Duration(seconds: 6);
    });

    try {
      await _runFixedDurationStep<void>(
        flow: myFlow,
        duration: const Duration(seconds: 6),
        action: () async => await _call119(),
      );
      _emergencyServicesCalled = true;

      if (!mounted || myFlow != _flowId) return;
      setState(() => _states[idx119] = StepState.done);

      await _goToResult(EmergencySummary(
        outcome: EmergencyOutcome.completed,
        someoneAnswered: _someoneAnswered,
        emergencyServicesCalled: _emergencyServicesCalled,
      ));
    } catch (_) {
      if (!mounted || myFlow != _flowId) return;
      setState(() => _states[idx119] = StepState.failed);

      await _goToResult(EmergencySummary(
        outcome: EmergencyOutcome.failed,
        someoneAnswered: _someoneAnswered,
        emergencyServicesCalled: _emergencyServicesCalled,
        failedStepIndex: idx119,
        failedStepTitle: _steps[idx119].title,
      ));
    }
  }

  // ---------- Replace with real logic later ----------
  Future<void> _messageAll() async {
    if (widget.onMessageAllContacts != null) {
      await widget.onMessageAllContacts!();
      return;
    }
    await Future.delayed(const Duration(milliseconds: 600));
  }

  Future<bool> _callContact(int contactIndex) async {
    if (widget.onCallContact != null) {
      return await widget.onCallContact!(contactIndex);
    }
    await Future.delayed(const Duration(milliseconds: 600));
    final answered = (DateTime.now().millisecondsSinceEpoch % 5) == 0;
    return answered;
  }

  Future<void> _call119() async {
    if (widget.onCall119 != null) {
      await widget.onCall119!();
      return;
    }
    await Future.delayed(const Duration(milliseconds: 600));
  }

  // ---------- UI helpers ----------
  double get _overallProgress {
    final totalMs =
        _steps.fold<int>(0, (sum, s) => sum + s.duration.inMilliseconds);

    int doneMs = 0;
    for (int i = 0; i < _steps.length; i++) {
      final st = _states[i];
      if (st == StepState.done || st == StepState.skipped) {
        doneMs += _steps[i].duration.inMilliseconds;
      }
    }

    final runningExtra = (_states[_currentIndex] == StepState.running)
        ? (_steps[_currentIndex].duration.inMilliseconds * _stepProgress).toInt()
        : 0;

    return ((doneMs + runningExtra) / totalMs).clamp(0.0, 1.0);
  }

  Color _stateColor(StepState s) {
    switch (s) {
      case StepState.done:
        return Colors.greenAccent;
      case StepState.running:
        return accentBlue;
      case StepState.skipped:
        return Colors.grey;
      case StepState.failed:
        return dangerRed;
      case StepState.pending:
      default:
        return Colors.white70;
    }
  }

  IconData _stateIcon(StepState s) {
    switch (s) {
      case StepState.done:
        return Icons.check_circle;
      case StepState.running:
        return Icons.autorenew;
      case StepState.skipped:
        return Icons.fast_forward;
      case StepState.failed:
        return Icons.error;
      case StepState.pending:
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Widget _chipForState(StepState st) {
    String text;
    switch (st) {
      case StepState.pending:
        text = "PENDING";
        break;
      case StepState.running:
        text = "RUNNING";
        break;
      case StepState.done:
        text = "DONE";
        break;
      case StepState.skipped:
        text = "SKIPPED";
        break;
      case StepState.failed:
        text = "FAILED";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _stateColor(st).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stateColor(st).withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _stateColor(st),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatMs(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m <= 0) return "${s}s";
    return "${m}m ${s}s";
  }

  // ✅ Overflow-safe button: Flexible text + short labels on tight width
  Widget _button({
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool tight = constraints.maxWidth < 150;

            String shown = label;
            if (tight) {
              if (label == "NOTIFY ALL INSTANTLY") shown = "NOTIFY ALL";
              if (label == "STOP PROCESS") shown = "STOP";
              if (label == "CALL 119 NOW") shown = "CALL 119";
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: fg, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    shown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _headerCard() {
    final overallPercent = (_overallProgress * 100).round();
    final isRunning = _states[_currentIndex] == StepState.running;

    final statusLine = _someoneAnswered
        ? "Someone answered — skipping remaining calls"
        : (isRunning ? "Running emergency actions…" : "Preparing…");

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF15171B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: dangerRed.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: dangerRed.withOpacity(0.25)),
                ),
                child: Icon(Icons.sos_rounded, color: dangerRed, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Emergency Process",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accentBlue.withOpacity(0.28)),
                ),
                child: Text(
                  "$overallPercent%",
                  style: TextStyle(
                    color: accentBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 10),
          Text(statusLine, style: TextStyle(color: Colors.grey[300], fontSize: 12)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: _overallProgress,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(accentBlue),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Current: ${_steps[_currentIndex].title}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Text(
                  isRunning ? _formatMs(_stepRemaining) : "--",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (isRunning) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: _stepProgress,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation<Color>(dangerRed),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _states[_currentIndex] == StepState.running;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF15171B),
        title: const Text("Emergency"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ✅ Compact header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: _headerCard(),
            ),

            // ✅ Steps area (scrollable only here)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF15171B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    itemCount: _steps.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withOpacity(0.06),
                      height: 10,
                    ),
                    itemBuilder: (context, i) {
                      final step = _steps[i];
                      final st = _states[i];
                      final isCurrent = i == _currentIndex && st == StepState.running;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: isCurrent ? accentBlue.withOpacity(0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent ? accentBlue.withOpacity(0.25) : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(_stateIcon(st), color: _stateColor(st)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Duration: ${_formatMs(step.duration)}",
                                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                  ),
                                  if (isCurrent && isRunning) ...[
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        minHeight: 7,
                                        value: _stepProgress,
                                        backgroundColor: Colors.white.withOpacity(0.06),
                                        valueColor: AlwaysStoppedAnimation<Color>(dangerRed),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _chipForState(st),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // ✅ Controls ALWAYS visible at bottom (no long scroll)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        final narrow = c.maxWidth < 360;

                        if (narrow) {
                          return Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: _button(
                                  label: "STOP PROCESS",
                                  bg: tealBtn,
                                  fg: Colors.black,
                                  icon: Icons.stop_circle_rounded,
                                  onTap: () async => await _stopProcess(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: _button(
                                  label: "CALL 119 NOW",
                                  bg: dangerRed,
                                  fg: Colors.white,
                                  icon: Icons.local_phone_rounded,
                                  onTap: () async => await _call119NowTakeOver(),
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: _button(
                                label: "STOP PROCESS",
                                bg: tealBtn,
                                fg: Colors.black,
                                icon: Icons.stop_circle_rounded,
                                onTap: () async => await _stopProcess(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _button(
                                label: "CALL 119 NOW",
                                bg: dangerRed,
                                fg: Colors.white,
                                icon: Icons.local_phone_rounded,
                                onTap: () async => await _call119NowTakeOver(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: _button(
                        label: "NOTIFY ALL INSTANTLY",
                        bg: accentBlue,
                        fg: Colors.white,
                        icon: Icons.flash_on_rounded,
                        onTap: () async => await _notifyAllInstantlyTakeOver(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
