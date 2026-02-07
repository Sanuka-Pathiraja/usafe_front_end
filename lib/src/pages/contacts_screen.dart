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
  static const int _minContacts = 3;
  static const int _maxContacts = 5;

  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  /* ================= LOAD CONTACTS FROM BACKEND ================= */

  Future<void> _loadContacts() async {
    try {
      final data = await AuthService.getContacts();
      setState(() {
        _contacts = data;
        _loading = false;
      });
    } catch (e) {
      _showSnack("Failed to load contacts");
      setState(() => _loading = false);
    }
  }

  /* ================= ADD CONTACT FROM PHONE ================= */

  Future<void> addContactFromPhone() async {
    if (_contacts.length >= _maxContacts) {
      _showSnack("You can add up to $_maxContacts contacts only");
      return;
    }

    final granted = await FlutterContacts.requestPermission();
    if (!granted) {
      _showSnack("Contacts permission required");
      return;
    }

    final picked = await FlutterContacts.openExternalPick();
    if (picked == null) return;

    final fullContact =
        await FlutterContacts.getContact(picked.id, withProperties: true);

    if (fullContact == null || fullContact.phones.isEmpty) {
      _showSnack("No phone number found");
      return;
    }

    final phone = await _pickPhoneNumber(fullContact.phones);
    if (phone == null) return;

    final relationship = await _promptRelation();
    if (relationship == null) return;

    final name = fullContact.displayName.trim().isNotEmpty
        ? fullContact.displayName
        : "Unknown";

    try {
      await AuthService.addContact(
        name: name,
        phone: phone,
        relationship: relationship,
      );

      await _loadContacts(); // refresh from backend
    } catch (e) {
      _showSnack("Failed to save contact");
    }
  }

  /* ================= PICK PHONE NUMBER ================= */

  Future<String?> _pickPhoneNumber(List<Phone> phones) async {
    if (phones.length == 1) return phones.first.number;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1B2026),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ListView.builder(
          itemCount: phones.length,
          itemBuilder: (_, i) {
            return ListTile(
              title: Text(
                phones[i].number,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, phones[i].number),
            );
          },
        );
      },
    );
  }

  /* ================= RELATIONSHIP PROMPT ================= */

  Future<String?> _promptRelation() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B2026),
        title:
            const Text("Relationship", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Mother / Father / Partner",
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    controller.dispose();
    return result == null || result.isEmpty ? null : result;
  }

  /* ================= DELETE CONTACT ================= */

  Future<void> _deleteContact(int contactId) async {
    try {
      await AuthService.deleteContact(contactId);
      await _loadContacts();
    } catch (e) {
      _showSnack("Failed to delete contact");
    }
  }

  /* ================= UI ================= */

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text("Emergency Contacts"),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        onPressed: addContactFromPhone,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "${_contacts.length}/$_maxContacts contacts added",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _contacts.length,
                    itemBuilder: (_, index) =>
                        _buildContactCard(_contacts[index]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    return Card(
      color: const Color(0xFF1A2128),
      margin: const EdgeInsets.all(10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade800,
          child: Text(contact["name"][0]),
        ),
        title: Text(
          contact["name"],
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          contact["relationship"],
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () => _deleteContact(contact["contactId"]),
        ),
      ),
    );
  }
}
