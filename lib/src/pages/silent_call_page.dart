import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/core/services/contact_alert_service.dart';
import 'package:usafe_front_end/features/onboarding/onboarding_controller.dart';
import 'package:showcaseview/showcaseview.dart';

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
  final Set<String> _selectedContactKeys = <String>{};
  String? _validationMessage;
  bool _sending = false;
  bool _tourRequested = false;
  final GlobalKey _messageFieldKey = GlobalKey();
  final GlobalKey _contactsListKey = GlobalKey();
  final GlobalKey _sendButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: _defaultMessage);
    _selectedContactKeys.addAll(
      widget.contacts.map(_contactKey).where((key) => key.trim().isNotEmpty),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _contactKey(Map<String, String> contact) {
    final contactId = (contact['contactId'] ?? '').trim();
    if (contactId.isNotEmpty) return contactId;
    return '${contact['name'] ?? ''}|${contact['phone'] ?? ''}';
  }

  List<Map<String, String>> _selectedContacts() {
    return widget.contacts
        .where((contact) => _selectedContactKeys.contains(_contactKey(contact)))
        .toList();
  }

  Future<void> _handleSend() async {
    if (_sending) return;

    final trimmedMessage = _messageController.text.trim();
    final selectedContacts = _selectedContacts();

    if (trimmedMessage.isEmpty) {
      setState(() {
        _validationMessage = 'Please enter your emergency message.';
      });
      return;
    }

    if (selectedContacts.isEmpty) {
      setState(() {
        _validationMessage = 'Select at least one emergency contact.';
      });
      return;
    }

    final invalidContacts = selectedContacts
        .where((contact) =>
            ContactAlertService.normalizePhoneNumber(contact['phone'] ?? '')
                .isEmpty)
        .map((contact) => contact['name'] ?? 'Unknown contact')
        .toList();

    if (invalidContacts.isNotEmpty) {
      setState(() {
        _validationMessage =
            'These contacts do not have valid phone numbers: ${invalidContacts.join(', ')}';
      });
      return;
    }

    setState(() {
      _sending = true;
      _validationMessage = null;
    });

    try {
      await widget.onSend(trimmedMessage, selectedContacts);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _maybeStartSilentCallTour(BuildContext showcaseContext) async {
    if (_tourRequested) {
      return;
    }
    _tourRequested = true;

    final shouldShow = await OnboardingController.shouldShowSilentCallTour();
    if (!shouldShow) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final showcase = ShowCaseWidget.of(showcaseContext);
      if (showcase == null) return;
      showcase.startShowCase(
        [_messageFieldKey, _contactsListKey, _sendButtonKey],
      );
    });

    await OnboardingController.markSilentCallTourSeen();
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) {
        _maybeStartSilentCallTour(context);
        return Scaffold(
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
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
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
                  Showcase(
                    key: _messageFieldKey,
                    description:
                        'Customize the emergency message that will be sent silently.',
                    child: TextField(
                      controller: _messageController,
                      minLines: 5,
                      maxLines: 7,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Emergency message',
                        labelStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        hintText: 'Type your emergency message',
                        hintStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.border),
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
                  const Text(
                    'Emergency Contacts',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Showcase(
                    key: _contactsListKey,
                    description:
                        'Choose one or more contacts who should receive your silent alert.',
                    child: widget.contacts.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'No emergency contacts available.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: widget.contacts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final contact = widget.contacts[index];
                              final key = _contactKey(contact);
                              final selected =
                                  _selectedContactKeys.contains(key);
                              final phone = contact['phone'] ?? '';
                              final normalizedPhone =
                                  ContactAlertService.normalizePhoneNumber(
                                      phone);
                              final hasValidPhone = normalizedPhone.isNotEmpty;

                              return InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: _sending
                                    ? null
                                    : () {
                                        setState(() {
                                          if (selected) {
                                            _selectedContactKeys.remove(key);
                                          } else {
                                            _selectedContactKeys.add(key);
                                          }
                                          _validationMessage = null;
                                        });
                                      },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primary.withOpacity(0.18)
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(18),
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
                                                  _validationMessage = null;
                                                });
                                              },
                                        activeColor: AppColors.primary,
                                        side: const BorderSide(
                                            color: AppColors.border),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              contact['name'] ?? 'Unknown',
                                              style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w700,
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
                                                    ? AppColors.textSecondary
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _sending
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Showcase(
                          key: _sendButtonKey,
                          description:
                              'Tap Send to notify selected contacts immediately.',
                          child: ElevatedButton(
                            onPressed: _sending ? null : _handleSend,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.primary.withOpacity(0.55),
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
