import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => ContactsScreenState();
}

class ContactsScreenState extends State<ContactsScreen> {
  // Min/max constraints for trusted contacts.
  static const int _minContacts = 3;
  static const int _maxContacts = 5;
  static const double _footerHeight = 70;
  static const double _footerBottom = 30;
  static const double _fabSize = 56;

  final List<Map<String, String>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Load persisted contacts on startup.
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    await MockDatabase.loadTrustedContacts();
    setState(() {
      _contacts
        ..clear()
        ..addAll(MockDatabase.trustedContacts);
      _loading = false;
    });
  }

  Future<void> _addContactFromPhone() async {
    // Enforce limits and request phonebook permission.
    if (_contacts.length >= _maxContacts) {
      _showSnack('You can add up to $_maxContacts contacts only.');
      return;
    }

    final bool granted = await FlutterContacts.requestPermission();
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

    setState(() {
      _contacts.add({
        'name': name,
        'relation': relation,
        'phone': phone,
      });
    });

    await MockDatabase.saveTrustedContacts(_contacts);
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
      backgroundColor: const Color(0xFF1B2026),
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
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B2026),
          title: const Text('Relationship',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
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
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                final relation = controller.text.trim();
                Navigator.pop(context, relation.isEmpty ? 'Contact' : relation);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _removeContact(int index) async {
    // Persist removals immediately.
    setState(() {
      _contacts.removeAt(index);
    });
    await MockDatabase.saveTrustedContacts(_contacts);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add ${_minContacts}-$_maxContacts trusted contacts',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '${_contacts.length}/$_maxContacts',
                        style: TextStyle(
                          color: _contacts.length < _minContacts
                              ? Colors.orangeAccent
                              : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_contacts.length < _minContacts)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                    child: Text(
                      'Add at least $_minContacts contacts to enable alerts.',
                      style: TextStyle(
                        color: Colors.orange.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      return _buildContactCard(contact, index);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildContactCard(Map<String, String> contact, int index) {
    final String name = contact['name'] ?? 'Unknown';
    final String relation = contact['relation'] ?? 'Contact';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2128),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF2B3440),
                child: Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      relation,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.white54),
                onPressed: () => _showContactActions(index),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.warning_amber_rounded,
                      size: 18, color: Colors.white),
                  label: const Text('Alert'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

  void _showContactActions(int index) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B2026),
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
