import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/core/services/contact_alert_service.dart';
import 'package:usafe_front_end/core/services/phone_call_service.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/src/pages/silent_call_page.dart';
import 'package:usafe_front_end/src/widgets/contact_alert_bottom_sheet.dart';
import 'package:usafe_front_end/features/onboarding/onboarding_controller.dart';

class ContactsScreen extends StatefulWidget {
  final VoidCallback? onBackHome;
  // Kept for backward compatibility with existing callers — no longer used.
  // ignore: unused_element
  final GlobalKey? infoKey;
  // ignore: unused_element
  final GlobalKey? silentCallKey;

  const ContactsScreen({
    super.key,
    this.onBackHome,
    this.infoKey,
    this.silentCallKey,
  });

  @override
  State<ContactsScreen> createState() => ContactsScreenState();
}

class ContactsScreenState extends State<ContactsScreen> {
  // Min/max constraints for trusted contacts.
  static const int _minContacts = 3;
  static const int _maxContacts = 5;

  final List<Map<String, String>> _contacts = [];
  bool _loading = true;
  final Completer<int> _loadedCountCompleter = Completer<int>();

  // ── Onboarding tour ──────────────────────────────────────────────────────
  final GlobalKey _guideInfoKey = GlobalKey();
  final GlobalKey _guideListKey = GlobalKey();
  final GlobalKey _guideFabKey = GlobalKey();
  bool _wasCurrentRoute = false;
  bool _guideInFlight = false;
  bool _pendingGuideCheck = false;

  void _logContactAlert(String message) {
    debugPrint('[ContactAlertUI] $message');
  }

  Map<String, Color> _silentCallColors(BuildContext context) {
    final background = AppColors.alert;
    final foreground = Colors.white;
    final shadow = Color.lerp(background, Colors.black, 0.34)!;

    return <String, Color>{
      'background': background,
      'foreground': foreground,
      'shadow': shadow,
    };
  }

  Map<String, Color> _silentCallRingColors(BuildContext context) {
    final colors = _silentCallColors(context);
    final background = colors['background']!;
    final foreground = colors['foreground']!;

    return <String, Color>{
      'outer': AppColors.alert.withOpacity(0.78),
      'inner': Color.lerp(background, Colors.white, 0.08)!,
      'foregroundSoft': foreground.withOpacity(0.92),
    };
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _pendingGuideCheck = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute fires for ALL IndexedStack children when any route is
    // pushed/popped. We mark a pending check here and gate it in build()
    // by confirming the contacts tab is the active IndexedStack child.
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    if (isCurrentRoute && !_wasCurrentRoute) {
      setState(() => _pendingGuideCheck = true);
    }
    _wasCurrentRoute = isCurrentRoute;
  }

  Future<void> _checkOnboarding() async {
    if (_guideInFlight || !mounted) return;
    final should = await OnboardingController.shouldShowContactsPageTour();
    if (!should || !mounted) return;
    _guideInFlight = true;
    await OnboardingController.markContactsPageTourSeen();
    if (!mounted) {
      _guideInFlight = false;
      return;
    }
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, __) => _ContactsOnboardingOverlay(
        onDone: () => Navigator.of(ctx).pop(),
        stepKeys: [_guideInfoKey, _guideListKey, _guideFabKey],
      ),
    );
    _guideInFlight = false;
  }

  Future<void> _loadContacts() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      setState(() {
        _contacts.clear();
        _loading = false;
      });
      return;
    }

    try {
      final remote = await AuthService.fetchContacts();
      setState(() {
        _contacts
          ..clear()
          ..addAll(remote.map((e) => <String, String>{
                'contactId': (e['contactId'] ?? '').toString(),
                'name': (e['name'] ?? '').toString(),
                'relationship': (e['relationship'] ?? 'Contact').toString(),
                'phone': (e['phone'] ?? '').toString(),
              }));
        _loading = false;
      });
      if (!_loadedCountCompleter.isCompleted) {
        _loadedCountCompleter.complete(_contacts.length);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _contacts.clear();
        _loading = false;
      });
      if (!_loadedCountCompleter.isCompleted) {
        _loadedCountCompleter.complete(0);
      }
      final error = e.toString().replaceFirst('Exception: ', '');
      if (!error.toLowerCase().contains('not authenticated')) {
        _showSnack(error);
      }
    }
  }

  Future<int> waitForLoadedContactCount() {
    if (!_loading) {
      return Future.value(_contacts.length);
    }
    return _loadedCountCompleter.future;
  }

  Future<void> _addContactFromPhone() async {
    // Enforce limits and request phonebook permission.
    if (_contacts.length >= _maxContacts) {
      _showSnack('You can add up to $_maxContacts contacts only.');
      return;
    }

    // Read-only is enough for picking a contact; requesting write can be denied
    // on some devices even when contact access is already allowed.
    final bool granted =
        await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      _showSnack('Contacts permission is required to add a contact.');
      return;
    }

    final Contact? picked = await FlutterContacts.openExternalPick();
    if (picked == null) return;

    // Fetch full details and let the user pick a number + relation.
    final Contact? fullContact =
        await FlutterContacts.getContact(picked.id, withProperties: true);
    if (fullContact == null || fullContact.phones.isEmpty) {
      _showSnack('This contact does not have a phone number.');
      return;
    }

    final String? phone = await _pickPhoneNumber(fullContact.phones);
    if (phone == null) return;

    final String? relation = await _promptRelation();
    if (relation == null) return;

    final String name = fullContact.displayName.trim().isNotEmpty
        ? fullContact.displayName
        : 'Unknown';

    try {
      final created = await AuthService.createContact(
        name: name,
        phone: phone,
        relationship: relation,
      );
      setState(() {
        _contacts.add({
          'contactId': (created['contactId'] ?? '').toString(),
          'name': (created['name'] ?? name).toString(),
          'relationship': (created['relationship'] ?? relation).toString(),
          'phone': (created['phone'] ?? phone).toString(),
        });
      });
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> openAddContact() async {
    // Public entry point used by the Home FAB.
    await _addContactFromPhone();
  }

  Future<String?> _pickPhoneNumber(List<Phone> phones) async {
    // If multiple numbers exist, show a sheet to choose one.
    if (phones.length == 1) {
      return phones.first.number;
    }

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: phones.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final phone = phones[index].number;
              return ListTile(
                title: Text(phone, style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, phone),
              );
            },
          ),
        );
      },
    );
  }

  Future<String?> _promptRelation() async {
    // Ask the user how this contact is related.
    String relationInput = '';

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title:
              const Text('Relationship', style: TextStyle(color: Colors.white)),
          content: TextField(
            onChanged: (value) => relationInput = value,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Mother, Partner',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                final relation = relationInput.trim();
                Navigator.pop(context, relation.isEmpty ? 'Contact' : relation);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    return result;
  }

  Future<void> _removeContact(int index) async {
    final contactId = _contacts[index]['contactId'] ?? '';
    if (contactId.isEmpty) {
      _showSnack('Invalid contact id.');
      return;
    }
    try {
      await AuthService.deleteContact(contactId);
      setState(() {
        _contacts.removeAt(index);
      });
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showAlertComposer(Map<String, String> contact) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ContactAlertBottomSheet(
          contact: contact,
          onSend: (message) => _sendAlertToContact(contact, message),
        );
      },
    );
  }

  Future<void> _showSilentCallComposer() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SilentCallPage(
          contacts: List<Map<String, String>>.from(_contacts),
          onSend: _sendSilentCall,
        ),
      ),
    );
  }

  Future<void> _sendAlertToContact(
    Map<String, String> contact,
    String message,
  ) async {
    final name = contact['name'] ?? 'contact';
    final contactId = contact['contactId'] ?? '';
    final phone = contact['phone'] ?? '';
    final normalizedPhone = ContactAlertService.normalizePhoneNumber(phone);

    if (normalizedPhone.isEmpty) {
      throw Exception('No phone number found for $name.');
    }
    if (message.trim().isEmpty) {
      throw Exception('Emergency message cannot be empty.');
    }

    try {
      _logContactAlert(
        'Starting send for $name. contactId=${contactId.isEmpty ? 'n/a' : contactId}, phone=$normalizedPhone, messageLength=${message.trim().length}',
      );
      final serverMessage = await ContactAlertService.sendEmergencyMessage(
        contactId: contactId,
        phoneNumber: phone,
        message: message,
      );
      _logContactAlert(
          'Send completed for $name. serverMessage=$serverMessage');
      _showSnack(
        serverMessage.trim().isEmpty
            ? 'Emergency alert sent to $name.'
            : serverMessage,
      );
    } catch (e) {
      final error = e.toString().replaceFirst('Exception: ', '');
      _logContactAlert('Send failed for $name. error=$error');
      _showSnack(error);
      rethrow;
    }
  }

  Future<void> _callContact(Map<String, String> contact) async {
    final name = contact['name'] ?? 'contact';
    final phone = contact['phone'] ?? '';

    try {
      final launchMode = await PhoneCallService.call(phone);
      if (!mounted) return;

      if (launchMode == PhoneCallLaunchMode.dialer) {
        _showSnack('Opened your phone app for $name.');
      }
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _sendSilentCall(
    String message,
    List<Map<String, String>> selectedContacts,
  ) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw Exception('Emergency message cannot be empty.');
    }
    if (selectedContacts.isEmpty) {
      throw Exception('Select at least one emergency contact.');
    }

    final normalizedContacts = <Map<String, String>>[];
    for (final contact in selectedContacts) {
      final normalizedPhone = ContactAlertService.normalizePhoneNumber(
        contact['phone'] ?? '',
      );
      if (normalizedPhone.isEmpty) {
        final name = contact['name'] ?? 'Unknown contact';
        throw Exception('No valid phone number found for $name.');
      }
      normalizedContacts.add({
        'contactId': (contact['contactId'] ?? '').trim(),
        'name': (contact['name'] ?? '').trim(),
        'phone': normalizedPhone,
      });
    }

    try {
      debugPrint(
        '[SilentCallUI] Starting send. contacts=${normalizedContacts.length}, messageLength=${trimmedMessage.length}',
      );
      final response = await AuthService.sendSilentCall(
        message: trimmedMessage,
        contacts: normalizedContacts,
      );
      final serverMessage =
          (response['message'] ?? 'Silent Call request sent successfully.')
              .toString();
      debugPrint(
        '[SilentCallUI] Send completed. response=${response.toString()}',
      );
      _showSnack(serverMessage);
    } catch (e) {
      final error = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[SilentCallUI] Send failed. error=$error');
      _showSnack(error);
      rethrow;
    }
  }

  Widget _buildSilentCallFab(BuildContext context) {
    final colors = _silentCallColors(context);
    final ringColors = _silentCallRingColors(context);
    final background = colors['background']!;
    final foreground = colors['foreground']!;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: background.withOpacity(0.16),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ringColors['inner']!,
              background,
            ],
          ),
          border: Border.all(
            color: ringColors['outer']!,
            width: 1.8,
          ),
        ),
        child: FloatingActionButton(
          heroTag: 'silent-call-fab',
          tooltip: 'Silent Call',
          elevation: 0,
          highlightElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: foreground,
          disabledElevation: 0,
          onPressed: _loading ? null : _showSilentCallComposer,
          shape: const CircleBorder(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.volume_off_rounded,
                size: 24,
                color: Colors.white,
              ),
              const SizedBox(height: 3),
              Text(
                'Silent\nCall',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only fire the guide when the contacts tab is actually visible.
    // IndexedStack does NOT set TickerMode on inactive children, so we must
    // inspect the ancestor IndexedStack's current index directly.
    if (_pendingGuideCheck) {
      final stack = context.findAncestorWidgetOfExactType<IndexedStack>();
      // index 2 = contacts tab; null means ContactsScreen is shown standalone
      final isActiveTab = stack == null || stack.index == 2;
      if (isActiveTab) {
        _pendingGuideCheck = false;
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            if (widget.onBackHome != null) {
              widget.onBackHome!();
              return;
            }
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(key: _guideInfoKey, child: _buildContactsInfoRow()),
          ),
          if (_contacts.length < _minContacts)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: Text(
                'Add at least $_minContacts contacts to enable alerts.',
                style: TextStyle(
                  color: AppColors.alert.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _contacts.isEmpty
                    ? const Center(
                        child: Text(
                          'No trusted contacts found.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        key: _guideListKey,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 210),
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final contact = _contacts[index];
                          return _buildContactCard(contact, index);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 88),
        child: SizedBox(
          key: _guideFabKey,
          child: _buildSilentCallFab(context),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildContactCard(Map<String, String> contact, int index) {
    final String name = contact['name'] ?? 'Unknown';
    final String relation =
        contact['relationship'] ?? contact['relation'] ?? 'Contact';
    final String phone = contact['phone'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.25),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                child: Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      relation,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz,
                    color: AppColors.textSecondary),
                onPressed: () => _showContactActions(index),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callContact(contact),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAlertComposer(contact),
                  icon: const Icon(Icons.warning_amber_rounded,
                      size: 18, color: Colors.white),
                  label: const Text('Alert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.alert,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactsInfoRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Add ${_minContacts}-$_maxContacts trusted contacts',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          '${_contacts.length}/$_maxContacts',
          style: TextStyle(
            color: _contacts.length < _minContacts
                ? AppColors.alert
                : AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showContactActions(int index) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Remove Contact',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _removeContact(index);
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cinematic first-time guide overlay — Emergency Contacts
// ─────────────────────────────────────────────────────────────────────────────

class _ContactsTourStep {
  final IconData icon;
  final Color color;
  final String label;
  final String title;
  final String body;
  const _ContactsTourStep({
    required this.icon,
    required this.color,
    required this.label,
    required this.title,
    required this.body,
  });
}

const _kContactsSteps = [
  _ContactsTourStep(
    icon: Icons.people_alt_rounded,
    color: Color(0xFF3B82F6),
    label: 'Contact status',
    title: 'Your trusted contacts',
    body:
        'You need at least 3 trusted contacts to send emergency alerts.\nThis bar shows how many you\'ve added so far.',
  ),
  _ContactsTourStep(
    icon: Icons.contact_page_rounded,
    color: Color(0xFF10B981),
    label: 'Contact cards',
    title: 'Manage your contacts',
    body:
        'Each card shows a trusted person who can receive your SOS alerts.\nTap the ··· menu to remove a contact, or call them directly.',
  ),
  _ContactsTourStep(
    icon: Icons.volume_off_rounded,
    color: Color(0xFFEF4444),
    label: 'Silent Call',
    title: 'Silent SOS call',
    body:
        'Send a discreet emergency message to selected contacts with no sound, no visible call — just silent help on the way.',
  ),
];

class _ContactsSpotlightPainter extends CustomPainter {
  final Rect? highlight;
  final Color glowColor;
  final double glowT;

  const _ContactsSpotlightPainter({
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

    final overlay = Path()..addRect(screen);
    final hole = Path()..addRRect(rrect);
    final cutout = Path.combine(PathOperation.difference, overlay, hole);
    canvas.drawPath(
        cutout, Paint()..color = Colors.black.withValues(alpha: 0.86));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = glowColor.withValues(alpha: 0.06 + 0.04 * glowT)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inflated.inflate(6), radius),
      Paint()
        ..color = glowColor.withValues(alpha: 0.18 * glowT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = glowColor.withValues(alpha: 0.45 * glowT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = glowColor.withValues(alpha: 0.65 + 0.35 * glowT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_ContactsSpotlightPainter old) =>
      old.highlight != highlight ||
      old.glowColor != glowColor ||
      old.glowT != glowT;
}

class _ContactsOnboardingOverlay extends StatefulWidget {
  final VoidCallback onDone;
  final List<GlobalKey> stepKeys;

  const _ContactsOnboardingOverlay({
    required this.onDone,
    required this.stepKeys,
  });

  @override
  State<_ContactsOnboardingOverlay> createState() =>
      _ContactsOnboardingOverlayState();
}

class _ContactsOnboardingOverlayState
    extends State<_ContactsOnboardingOverlay> with TickerProviderStateMixin {
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollAndMeasure());
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _slideCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  Future<void> _scrollAndMeasure() async {
    final key = widget.stepKeys[_step];
    if (key.currentContext == null) return;
    try {
      await Scrollable.ensureVisible(
        key.currentContext!,
        alignment: 0.15,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } catch (_) {}
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
    if (_step < _kContactsSteps.length - 1) {
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
    final step = _kContactsSteps[_step];
    final color = step.color;
    final isLast = _step == _kContactsSteps.length - 1;
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;
    final bottomPad = mq.padding.bottom;
    final screenH = mq.size.height;

    double? calloutTop;
    double? calloutBottom;
    if (_highlightRect != null) {
      // Need at least 60 px above the highlight (inflated rect) to show the
      // label above it without clipping into the status-bar / AppBar area.
      final inflatedTop = _highlightRect!.top - 10;
      final spaceAbove = inflatedTop - topPad - 60;
      if (spaceAbove >= 44) {
        calloutTop = inflatedTop - 44;
      } else {
        // Show label below the highlight with a comfortable gap
        calloutBottom = screenH - (_highlightRect!.bottom + 10) - 52;
      }
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: AnimatedBuilder(
                animation: _glowCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _ContactsSpotlightPainter(
                    highlight: _highlightRect,
                    glowColor: color,
                    glowT: 0.55 + 0.45 * _glowCtrl.value,
                  ),
                ),
              ),
            ),
          ),

          if (_highlightRect != null)
            AnimatedBuilder(
              animation: _rippleCtrl,
              builder: (_, __) {
                final t = _rippleCtrl.value;
                final expand = t * 18.0;
                final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.7;
                final rect = _highlightRect!.inflate(10 + expand);
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
                          border: Border.all(color: color, width: 2),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          if (_highlightRect != null)
            Positioned(
              top: calloutTop,
              bottom: calloutBottom,
              left: _highlightRect!.left,
              right: mq.size.width - _highlightRect!.right,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
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

          Positioned(
            top: topPad + 14,
            right: 20,
            child: GestureDetector(
              onTap: widget.onDone,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${_step + 1} of ${_kContactsSteps.length}',
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

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.28),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: _slideCtrl, curve: Curves.easeOutCubic)),
              child: Container(
                padding: EdgeInsets.fromLTRB(26, 24, 26, 20 + bottomPad),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(32)),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.07)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: List.generate(
                        _kContactsSteps.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _step ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _step
                                ? color
                                : Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
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
                          child: Icon(step.icon, color: color, size: 22),
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
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
