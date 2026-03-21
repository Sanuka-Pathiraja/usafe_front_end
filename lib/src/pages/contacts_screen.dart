import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/core/services/contact_alert_service.dart';
import 'package:usafe_front_end/core/services/phone_call_service.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/src/pages/silent_call_page.dart';
import 'package:usafe_front_end/src/widgets/contact_alert_bottom_sheet.dart';
import 'package:showcaseview/showcaseview.dart';

class ContactsScreen extends StatefulWidget {
  final VoidCallback? onBackHome;
  final GlobalKey? infoKey;
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
    // Load persisted contacts on startup.
    _loadContacts();
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
            child: (widget.infoKey == null)
                ? _buildContactsInfoRow()
                : Showcase(
                    key: widget.infoKey!,
                    description:
                        'Add at least $_minContacts trusted contacts to enable alerts.',
                    child: _buildContactsInfoRow(),
                  ),
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
        child: (widget.silentCallKey == null)
            ? _buildSilentCallFab(context)
            : Showcase(
                key: widget.silentCallKey!,
                description: 'Send a silent SOS message to selected contacts.',
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
