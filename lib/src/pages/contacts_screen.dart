import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
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

  Future<void> _loadContacts() async {
    try {
      final data = await AuthService.getContacts();
      if (mounted) {
        setState(() {
          _contacts = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnack("Error: ${e.toString()}");
        setState(() => _loading = false);
      }
    }
  }

  /* ================= ADD LOGIC ================= */
  Future<void> addContactFromPhone() async {
    if (_contacts.length >= _maxContacts) {
      _showSnack("Max $_maxContacts contacts allowed");
      return;
    }

    if (!await Permission.contacts.request().isGranted) {
      _showPermissionDialog();
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
    final relationship = await _promptRelation();
    if (phone == null || relationship == null) return;

    try {
      await AuthService.addContact(
        name: fullContact.displayName.isNotEmpty
            ? fullContact.displayName
            : "Unknown",
        phone: phone.replaceAll(RegExp(r'[^\d+]'), ''),
        relationship: relationship,
      );
      _showSnack("Contact saved!");
      _loadContacts();
    } catch (e) {
      _showSnack("Save failed: $e");
    }
  }

  /* ================= EDIT LOGIC ================= */
  Future<void> _editContact(Map<String, dynamic> contact) async {
    final newRelation = await _promptRelation();
    if (newRelation == null) return;

    try {
      setState(() => _loading = true);
      await AuthService.updateContact(
        contactId: contact["contactId"],
        relationship: newRelation,
      );
      _showSnack("Updated successfully");
      _loadContacts();
    } catch (e) {
      _showSnack("Update failed");
      setState(() => _loading = false);
    }
  }

  /* ================= DELETE LOGIC ================= */
  Future<void> _deleteContact(int contactId) async {
    try {
      await AuthService.deleteContact(contactId);
      _loadContacts();
    } catch (e) {
      _showSnack("Delete failed");
    }
  }

  /* ================= UI HELPERS ================= */

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> _pickPhoneNumber(List<Phone> phones) async {
    if (phones.length == 1) return phones.first.number;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1B2026),
      builder: (context) => ListView(
        shrinkWrap: true,
        children: phones
            .map((p) => ListTile(
                  title: Text(p.number,
                      style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, p.number),
                ))
            .toList(),
      ),
    );
  }

  Future<String?> _promptRelation() async {
    final relations = [
      "Mother",
      "Father",
      "Partner",
      "Sibling",
      "Friend",
      "Other"
    ];
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2026),
        title:
            const Text("Relationship", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: relations
                .map((r) => ListTile(
                      title: Text(r,
                          style: const TextStyle(color: Colors.white70)),
                      onTap: () => Navigator.pop(ctx, r),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showPermissionDialog() {
    // Re-implemented standard permission dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Permission Required"),
        content: const Text("Please enable contacts permission in settings."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text("Emergency Contacts"),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Single Add Button aligned to Top Right
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0, top: 8.0),
                    child: GestureDetector(
                      onTap: addContactFromPhone,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D3748),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Contact List
                Expanded(
                  child: _contacts.isEmpty
                      ? const Center(
                          child: Text(
                            "Add at least 3 emergency contacts",
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _contacts.length,
                          itemBuilder: (ctx, i) =>
                              _buildContactCard(_contacts[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    return Card(
      color: const Color(0xFF1E2530),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(contact["name"],
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500)),
        subtitle: Text(contact["relationship"],
            style: const TextStyle(color: Colors.white60)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.blueAccent, size: 22),
              onPressed: () => _editContact(contact),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 22),
              onPressed: () => _deleteContact(contact["contactId"]),
            ),
          ],
        ),
      ),
    );
  }
}
