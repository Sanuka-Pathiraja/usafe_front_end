import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/core/services/contact_alert_service.dart';
import 'package:usafe_front_end/features/onboarding/onboarding_controller.dart';

class SilentCallPage extends StatefulWidget {
  final List<Map<String, String>> contacts;
  final Future<void> Function(
    String message,
    List<Map<String, String>> selectedContacts,
  ) onSend;

  const SilentCallPage({
    super.key,
    required this.contacts,
    required this.onSend,
  });

  @override
  State<SilentCallPage> createState() => _SilentCallPageState();
}

class _SilentCallPageState extends State<SilentCallPage> {
  static const String _defaultMessage =
      'This is an emergency. I cannot speak right now. Please help me immediately.';

  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  final Set<String> _selectedContactKeys = <String>{};
  String? _validationMessage;
  bool _sending = false;
  bool _showOnboarding = false;

  // GlobalKeys so the overlay can measure each section's position
  final GlobalKey _messageKey = GlobalKey();
  final GlobalKey _contactsKey = GlobalKey();
  final GlobalKey _sendKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: _defaultMessage);
    _scrollController = ScrollController();
    _selectedContactKeys.addAll(
      widget.contacts.map(_contactKey).where((k) => k.trim().isNotEmpty),
    );
    _checkOnboarding();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkOnboarding() async {
    final should = await OnboardingController.shouldShowSilentCallTour();
    if (should && mounted) {
      setState(() => _showOnboarding = true);
      await OnboardingController.markSilentCallTourSeen();
    }
  }

  void _dismissOnboarding() => setState(() => _showOnboarding = false);

  String _contactKey(Map<String, String> contact) {
    final id = (contact['contactId'] ?? '').trim();
    if (id.isNotEmpty) return id;
    return '${contact['name'] ?? ''}|${contact['phone'] ?? ''}';
  }

  List<Map<String, String>> _selectedContacts() {
    return widget.contacts
        .where((c) => _selectedContactKeys.contains(_contactKey(c)))
        .toList();
  }

  Future<void> _handleSend() async {
    if (_sending) return;
    final msg = _messageController.text.trim();
    final contacts = _selectedContacts();

    if (msg.isEmpty) {
      setState(() => _validationMessage = 'Please enter your emergency message.');
      return;
    }
    if (contacts.isEmpty) {
      setState(
          () => _validationMessage = 'Select at least one emergency contact.');
      return;
    }
    final invalid = contacts
        .where((c) =>
            ContactAlertService.normalizePhoneNumber(c['phone'] ?? '').isEmpty)
        .map((c) => c['name'] ?? 'Unknown contact')
        .toList();
    if (invalid.isNotEmpty) {
      setState(() => _validationMessage =
          'These contacts do not have valid phone numbers: ${invalid.join(', ')}');
      return;
    }

    setState(() {
      _sending = true;
      _validationMessage = null;
    });
    try {
      await widget.onSend(msg, contacts);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Silent Call',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Type your emergency message and select contacts to notify',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Step 1: message field ──────────────────────────────
                  SizedBox(
                    key: _messageKey,
                    child: TextField(
                      controller: _messageController,
                      minLines: 5,
                      maxLines: 7,
                      textInputAction: TextInputAction.newline,
                      style:
                          const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Emergency message',
                        labelStyle: const TextStyle(
                            color: AppColors.textSecondary),
                        hintText: 'Type your emergency message',
                        hintStyle: const TextStyle(
                            color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Step 2: contacts ───────────────────────────────────
                  SizedBox(
                    key: _contactsKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Emergency Contacts',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        widget.contacts.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border:
                                      Border.all(color: AppColors.border),
                                ),
                                child: const Text(
                                  'No emergency contacts available.',
                                  style: TextStyle(
                                      color: AppColors.textSecondary),
                                ),
                              )
                            : ListView.separated(
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: widget.contacts.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final contact =
                                      widget.contacts[index];
                                  final key = _contactKey(contact);
                                  final selected =
                                      _selectedContactKeys.contains(key);
                                  final phone = contact['phone'] ?? '';
                                  final normalizedPhone =
                                      ContactAlertService
                                          .normalizePhoneNumber(phone);
                                  final hasValidPhone =
                                      normalizedPhone.isNotEmpty;

                                  return InkWell(
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    onTap: _sending
                                        ? null
                                        : () {
                                            setState(() {
                                              if (selected) {
                                                _selectedContactKeys
                                                    .remove(key);
                                              } else {
                                                _selectedContactKeys
                                                    .add(key);
                                              }
                                              _validationMessage = null;
                                            });
                                          },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 180),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppColors.primary
                                                .withValues(alpha: 0.18)
                                            : AppColors.surface,
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        border: Border.all(
                                          color: selected
                                              ? AppColors.primary
                                              : AppColors.border,
                                          width: selected ? 1.4 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: selected,
                                            onChanged: _sending
                                                ? null
                                                : (_) {
                                                    setState(() {
                                                      if (selected) {
                                                        _selectedContactKeys
                                                            .remove(key);
                                                      } else {
                                                        _selectedContactKeys
                                                            .add(key);
                                                      }
                                                      _validationMessage =
                                                          null;
                                                    });
                                                  },
                                            activeColor:
                                                AppColors.primary,
                                            side: const BorderSide(
                                                color: AppColors.border),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                                Text(
                                                  contact['name'] ??
                                                      'Unknown',
                                                  style: const TextStyle(
                                                    color: AppColors
                                                        .textPrimary,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  phone.trim().isEmpty
                                                      ? 'No phone number'
                                                      : phone,
                                                  style: TextStyle(
                                                    color: hasValidPhone
                                                        ? AppColors
                                                            .textSecondary
                                                        : AppColors.alert,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),

                  if (_validationMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _validationMessage!,
                      style: const TextStyle(
                        color: AppColors.alert,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Step 3: action row ─────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _sending
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side:
                                const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        key: _sendKey,
                        child: ElevatedButton(
                          onPressed: _sending ? null : _handleSend,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.primary.withValues(alpha: 0.55),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _sending
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Send'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Cinematic first-time guide overlay ─────────────────────────────
        if (_showOnboarding)
          _SilentCallOnboardingOverlay(
            onDone: _dismissOnboarding,
            stepKeys: [_messageKey, _contactsKey, _sendKey],
            scrollController: _scrollController,
          ),
      ],
    );
  }
}

// ── Step data ─────────────────────────────────────────────────────────────────

class _OnboardingStep {
  final IconData icon;
  final Color color;
  final String label; // short label shown near the highlight
  final String title;
  final String body;
  const _OnboardingStep({
    required this.icon,
    required this.color,
    required this.label,
    required this.title,
    required this.body,
  });
}

const _kSteps = [
  _OnboardingStep(
    icon: Icons.edit_note_rounded,
    color: Color(0xFF3B82F6),
    label: 'Emergency message',
    title: 'Your emergency message',
    body:
        'A message is pre-filled so you can act fast.\nEdit it to say exactly what you need — even a few words can save you.',
  ),
  _OnboardingStep(
    icon: Icons.people_alt_rounded,
    color: Color(0xFF10B981),
    label: 'Emergency contacts',
    title: 'Choose who gets alerted',
    body:
        'Select one or more trusted contacts.\nThey receive your message silently — no call sound, no trace.',
  ),
  _OnboardingStep(
    icon: Icons.send_rounded,
    color: Color(0xFFEF4444),
    label: 'Send button',
    title: 'Send in one tap',
    body:
        'Your contacts are notified instantly.\nNo rings. No noise. Just help on the way.',
  ),
];

// ── Spotlight painter ─────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect? highlight;
  final Color glowColor;
  final double glowT; // 0..1 animated value

  const _SpotlightPainter({
    required this.highlight,
    required this.glowColor,
    required this.glowT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Rect.fromLTWH(0, 0, size.width, size.height);

    if (highlight == null) {
      canvas.drawRect(
          screen, Paint()..color = Colors.black.withValues(alpha: 0.88));
      return;
    }

    const radius = Radius.circular(22);
    final inflated = highlight!.inflate(10);
    final rrect = RRect.fromRectAndRadius(inflated, radius);

    // 1 ── Dark overlay with the highlight punched out
    final overlay = Path()..addRect(screen);
    final hole = Path()..addRRect(rrect);
    final cutout =
        Path.combine(PathOperation.difference, overlay, hole);
    canvas.drawPath(
        cutout, Paint()..color = Colors.black.withValues(alpha: 0.86));

    // 2 ── Subtle colour wash inside the highlight
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = glowColor.withValues(alpha: 0.06 + 0.04 * glowT)
        ..style = PaintingStyle.fill,
    );

    // 3 ── Outer diffused glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(inflated.inflate(6), radius),
      Paint()
        ..color = glowColor.withValues(alpha: 0.18 * glowT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..maskFilter =
            const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // 4 ── Medium glow ring
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = glowColor.withValues(alpha: 0.45 * glowT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter =
            const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // 5 ── Crisp inner border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = glowColor.withValues(alpha: 0.65 + 0.35 * glowT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.highlight != highlight ||
      old.glowColor != glowColor ||
      old.glowT != glowT;
}

// ── Onboarding overlay ────────────────────────────────────────────────────────

class _SilentCallOnboardingOverlay extends StatefulWidget {
  final VoidCallback onDone;
  final List<GlobalKey> stepKeys;
  final ScrollController scrollController;

  const _SilentCallOnboardingOverlay({
    required this.onDone,
    required this.stepKeys,
    required this.scrollController,
  });

  @override
  State<_SilentCallOnboardingOverlay> createState() =>
      _SilentCallOnboardingOverlayState();
}

class _SilentCallOnboardingOverlayState
    extends State<_SilentCallOnboardingOverlay>
    with TickerProviderStateMixin {
  int _step = 0;
  Rect? _highlightRect;

  late final AnimationController _glowCtrl;
  late final AnimationController _slideCtrl;
  late final AnimationController _rippleCtrl;

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450))
      ..forward();

    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollAndMeasure());
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _slideCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  // ── Scroll page so the target element is visible, then measure its rect ──
  Future<void> _scrollAndMeasure() async {
    final key = widget.stepKeys[_step];
    if (key.currentContext == null) return;

    await Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.15,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOut,
    );

    // Wait one extra frame for layout to settle after scroll
    await Future.delayed(const Duration(milliseconds: 40));
    if (!mounted) return;
    _measureRect();
  }

  void _measureRect() {
    final key = widget.stepKeys[_step];
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final pos = box.localToGlobal(Offset.zero);
    if (mounted) setState(() => _highlightRect = pos & box.size);
  }

  Future<void> _advance() async {
    if (_step < _kSteps.length - 1) {
      // Clear rect so the painter draws a plain overlay during transition
      setState(() {
        _step++;
        _highlightRect = null;
      });
      _slideCtrl
        ..reset()
        ..forward();
      _rippleCtrl.reset();
      await _scrollAndMeasure();
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _kSteps[_step];
    final color = step.color;
    final isLast = _step == _kSteps.length - 1;
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;
    final bottomPad = mq.padding.bottom;
    final screenH = mq.size.height;

    // Position the callout label just above (or below) the highlight
    double? calloutTop;
    double? calloutBottom;
    if (_highlightRect != null) {
      final spaceAbove = _highlightRect!.top - topPad - 80;
      if (spaceAbove >= 40) {
        calloutTop = _highlightRect!.top - 48;
      } else {
        calloutBottom = screenH - _highlightRect!.bottom - 8;
      }
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Spotlight painter ─────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // trap touches
              child: AnimatedBuilder(
                animation: _glowCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _SpotlightPainter(
                    highlight: _highlightRect,
                    glowColor: color,
                    glowT: 0.55 + 0.45 * _glowCtrl.value,
                  ),
                ),
              ),
            ),
          ),

          // ── Expanding ripple on the highlighted section ───────────────
          if (_highlightRect != null)
            AnimatedBuilder(
              animation: _rippleCtrl,
              builder: (_, __) {
                final t = _rippleCtrl.value;
                final maxExpand = 18.0;
                final expand = t * maxExpand;
                final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.7;
                final rect =
                    _highlightRect!.inflate(10 + expand);
                return Positioned(
                  left: rect.left,
                  top: rect.top,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: rect.width,
                        height: rect.height,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border:
                              Border.all(color: color, width: 2),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // ── Callout label near highlight ──────────────────────────────
          if (_highlightRect != null)
            Positioned(
              top: calloutTop,
              bottom: calloutBottom,
              left: _highlightRect!.left,
              right: mq.size.width - _highlightRect!.right,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(step.icon, color: color, size: 13),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          step.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Skip button ───────────────────────────────────────────────
          Positioned(
            top: topPad + 14,
            right: 20,
            child: GestureDetector(
              onTap: widget.onDone,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // ── Step counter (top-centre, below status bar) ───────────────
          Positioned(
            top: topPad + 14,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: Container(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${_step + 1} of ${_kSteps.length}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Slide-up card ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.28),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: _slideCtrl,
                  curve: Curves.easeOutCubic)),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    26, 24, 26, 20 + bottomPad),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32)),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07)),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress dots
                    Row(
                      children: List.generate(
                        _kSteps.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _step ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _step
                                ? color
                                : Colors.white
                                    .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Icon + title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: color.withValues(alpha: 0.45)),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Icon(step.icon,
                              color: color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            child: Text(
                              step.title,
                              key: ValueKey('t$_step'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Body
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: Text(
                        step.body,
                        key: ValueKey('b$_step'),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // CTA button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.42),
                            blurRadius: 22,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _advance,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text(
                                isLast ? "Let's go" : 'Next',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isLast
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
