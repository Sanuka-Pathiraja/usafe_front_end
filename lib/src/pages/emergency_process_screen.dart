import 'dart:async';
import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';

enum EmergencyStepType { messageAll, callContact, waitBefore119, call119 }

class EmergencyStep {
  final String title;
  final EmergencyStepType type;
  final int? contactIndex; // 1..5 for contacts
  final Duration duration;

  const EmergencyStep(
    this.title,
    this.type, {
    this.contactIndex,
    required this.duration,
  });
}

enum StepState { pending, running, done, skipped, failed }

class EmergencyProcessResult {
  final bool stoppedByUser;
  final bool someoneAnswered;
  const EmergencyProcessResult({
    required this.stoppedByUser,
    required this.someoneAnswered,
  });
}

class EmergencyProcessScreen extends StatefulWidget {
  /// Optional real implementations (plug your APIs here later)
  final Future<void> Function()? onMessageAllContacts;

  /// Returns true if answered (so other calls can be skipped)
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

  bool _stopped = false; // user pressed STOP PROCESS (exit screen)
  bool _someoneAnswered = false;

  // Current step progress (0..1)
  double _stepProgress = 0.0;

  // Remaining time for current step (for UI)
  Duration _stepRemaining = Duration.zero;

  Timer? _stepTimer;

  /// Cancels any running async flow safely.
  /// Every time you start a new flow, increment this.
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

  // ---------------------------
  // FLOW CONTROL
  // ---------------------------

  void _cancelCurrentFlow({required bool keepScreenOpen}) {
    _flowId++; // invalidates all running async loops
    _stepTimer?.cancel();

    if (!keepScreenOpen) {
      _stopped = true;
    }
  }

  void _startDefaultProcess() {
    final myFlow = ++_flowId;
    _runDefaultSteps(myFlow);
  }

  Future<void> _runDefaultSteps(int myFlow) async {
    for (int i = 0; i < _steps.length; i++) {
      if (!mounted || _stopped || myFlow != _flowId) return;

      // If someone answered -> skip remaining contact calls
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
            break;
        }

        if (!mounted || _stopped || myFlow != _flowId) return;
        setState(() => _states[i] = StepState.done);
      } catch (_) {
        if (!mounted || _stopped || myFlow != _flowId) return;
        setState(() => _states[i] = StepState.failed);
      }
    }

    if (!mounted || _stopped || myFlow != _flowId) return;

    Navigator.pop(
      context,
      EmergencyProcessResult(stoppedByUser: false, someoneAnswered: _someoneAnswered),
    );
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
      if (!mounted || _stopped || flow != _flowId) return;

      final elapsed = stopwatch.elapsed;
      final remaining = duration - elapsed;
      _stepRemaining = remaining.isNegative ? Duration.zero : remaining;

      final p = elapsed.inMilliseconds / duration.inMilliseconds;
      setState(() => _stepProgress = p.clamp(0.0, 1.0));
    });

    // Run action while UI timer runs
    late T result;
    Object? err;
    try {
      result = await action();
    } catch (e) {
      err = e;
    }

    if (!mounted || _stopped || flow != _flowId) {
      _stepTimer?.cancel();
      throw StateError("Flow cancelled");
    }

    // Ensure the UI step lasts full duration
    final elapsed = stopwatch.elapsed;
    if (elapsed < duration && !_stopped && flow == _flowId) {
      await Future.delayed(duration - elapsed);
    }

    if (!mounted || _stopped || flow != _flowId) {
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

  // ---------------------------
  // ACTIONS: Manual override buttons
  // ---------------------------

  Future<void> _call119NowTakeOver() async {
    // Cancel default process but keep screen open
    _cancelCurrentFlow(keepScreenOpen: true);
    final myFlow = ++_flowId;

    // Update UI: skip everything except 119 (mark done/skipped appropriately)
    final int idx119 = _steps.indexWhere((s) => s.type == EmergencyStepType.call119);

    setState(() {
      for (int i = 0; i < _steps.length; i++) {
        if (i < idx119) {
          // if it was already done, keep done; else skip
          _states[i] = (_states[i] == StepState.done) ? StepState.done : StepState.skipped;
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
      if (!mounted || _stopped || myFlow != _flowId) return;
      setState(() => _states[idx119] = StepState.done);

      Navigator.pop(
        context,
        EmergencyProcessResult(stoppedByUser: false, someoneAnswered: _someoneAnswered),
      );
    } catch (_) {
      if (!mounted || _stopped || myFlow != _flowId) return;
      setState(() => _states[idx119] = StepState.failed);
    }
  }

  Future<void> _notifyAllInstantlyTakeOver() async {
    // Cancel default process but keep screen open
    _cancelCurrentFlow(keepScreenOpen: true);
    final myFlow = ++_flowId;

    // Reset some state for a clean “instant” run (optional)
    _someoneAnswered = false;

    // Which steps are used in instant flow: messageAll + callContact(s) + call119
    final msgIdx = _steps.indexWhere((s) => s.type == EmergencyStepType.messageAll);
    final callIdxs = <int>[];
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i].type == EmergencyStepType.callContact) callIdxs.add(i);
    }
    final idxWait = _steps.indexWhere((s) => s.type == EmergencyStepType.waitBefore119);
    final idx119 = _steps.indexWhere((s) => s.type == EmergencyStepType.call119);

    // Mark WAIT step as skipped in instant mode
    setState(() {
      for (int i = 0; i < _steps.length; i++) {
        if (i == idxWait) {
          _states[i] = StepState.skipped;
        } else if (_states[i] != StepState.done) {
          _states[i] = StepState.pending;
        }
      }
    });

    // Step 1: Message all
    setState(() {
      _currentIndex = msgIdx;
      _states[msgIdx] = StepState.running;
      _stepProgress = 0.0;
      _stepRemaining = _steps[msgIdx].duration;
    });

    try {
      // Keep original duration for message step (1 min) OR make it shorter?
      // You asked "instantly" — but you also want UI changes.
      // We'll use a shorter UI duration so it feels instant but still visible.
      const instantMsgDuration = Duration(seconds: 8);

      await _runFixedDurationStep<void>(
        flow: myFlow,
        duration: instantMsgDuration,
        action: () async => await _messageAll(),
      );

      if (!mounted || _stopped || myFlow != _flowId) return;
      setState(() => _states[msgIdx] = StepState.done);
    } catch (_) {
      if (!mounted || _stopped || myFlow != _flowId) return;
      setState(() => _states[msgIdx] = StepState.failed);
      return;
    }

    // Step 2: Call contacts quickly until someone answers
    for (final idx in callIdxs) {
      if (!mounted || _stopped || myFlow != _flowId) return;
      if (_someoneAnswered) {
        setState(() => _states[idx] = StepState.skipped);
        continue;
      }

      setState(() {
        _currentIndex = idx;
        _states[idx] = StepState.running;
        _stepProgress = 0.0;
        _stepRemaining = _steps[idx].duration;
      });

      try {
        const instantCallDuration = Duration(seconds: 6);

        final answered = await _runFixedDurationStep<bool>(
          flow: myFlow,
          duration: instantCallDuration,
          action: () async => await _callContact(_steps[idx].contactIndex!),
        );

        if (!mounted || _stopped || myFlow != _flowId) return;

        setState(() => _states[idx] = StepState.done);

        if (answered) {
          _someoneAnswered = true;
          // Skip remaining call steps in UI
          for (final laterIdx in callIdxs) {
            if (laterIdx > idx && _states[laterIdx] == StepState.pending) {
              _states[laterIdx] = StepState.skipped;
            }
          }
          if (mounted) setState(() {});
        }
      } catch (_) {
        if (!mounted || _stopped || myFlow != _flowId) return;
        setState(() => _states[idx] = StepState.failed);
        // continue to next call attempt, or stop? We'll continue.
      }
    }

    // Step 3: Call 119
    if (!mounted || _stopped || myFlow != _flowId) return;

    setState(() {
      _currentIndex = idx119;
      _states[idx119] = StepState.running;
      _stepProgress = 0.0;
      _stepRemaining = _steps[idx119].duration;
    });

    try {
      const instant119Duration = Duration(seconds: 6);

      await _runFixedDurationStep<void>(
        flow: myFlow,
        duration: instant119Duration,
        action: () async => await _call119(),
      );

      if (!mounted || _stopped || myFlow != _flowId) return;
      setState(() => _states[idx119] = StepState.done);

      Navigator.pop(
        context,
        EmergencyProcessResult(stoppedByUser: false, someoneAnswered: _someoneAnswered),
      );
    } catch (_) {
      if (!mounted || _stopped || myFlow != _flowId) return;
      setState(() => _states[idx119] = StepState.failed);
    }
  }

  void _stopProcessAndGoHome() {
    _cancelCurrentFlow(keepScreenOpen: false);
    Navigator.pop(
      context,
      EmergencyProcessResult(stoppedByUser: true, someoneAnswered: _someoneAnswered),
    );
  }

  // ---------------------------
  // Replace these with REAL logic later
  // ---------------------------

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

    // Simulated "answered": about 20% chance per call
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

  // ---------------------------
  // UI
  // ---------------------------

  double get _overallProgress {
    final totalMs = _steps.fold<int>(0, (sum, s) => sum + s.duration.inMilliseconds);

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

  Widget _button({
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          label,
          style: TextStyle(color: fg, fontWeight: FontWeight.bold),
        ),
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
        title: const Text("Emergency Process"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                _someoneAnswered
                    ? "Someone answered. Remaining calls will be skipped."
                    : "Following the emergency steps...",
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 14),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 12,
                  value: _overallProgress,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(accentBlue),
                ),
              ),

              const SizedBox(height: 10),
              if (isRunning)
                Text(
                  "Current step time left: ${_stepRemaining.inSeconds}s",
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),

              const SizedBox(height: 18),

              Expanded(
                child: ListView.separated(
                  itemCount: _steps.length,
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.white.withOpacity(0.06),
                    height: 1,
                  ),
                  itemBuilder: (context, i) {
                    final step = _steps[i];
                    final st = _states[i];
                    final isCurrent = i == _currentIndex && st == StepState.running;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                      leading: Icon(_stateIcon(st), color: _stateColor(st)),
                      title: Text(
                        step.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      subtitle: isCurrent
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  minHeight: 8,
                                  value: _stepProgress,
                                  backgroundColor: Colors.white.withOpacity(0.06),
                                  valueColor: AlwaysStoppedAnimation<Color>(dangerRed),
                                ),
                              ),
                            )
                          : null,
                      trailing: _chipForState(st),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _button(
                      label: "STOP PROCESS",
                      bg: tealBtn,
                      fg: Colors.black,
                      onTap: _stopProcessAndGoHome,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _button(
                      label: "CALL 119 NOW",
                      bg: dangerRed,
                      fg: Colors.white,
                      onTap: () async => await _call119NowTakeOver(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _button(
                  label: "NOTIFY ALL INSTANTLY",
                  bg: accentBlue,
                  fg: Colors.white,
                  onTap: () async => await _notifyAllInstantlyTakeOver(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
