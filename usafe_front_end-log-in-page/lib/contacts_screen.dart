import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'config.dart'; // Imports AppColors

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // Example Data
  final List<Map<String, String>> _emergencyContacts = [
    {
      'name': 'Jane Doe',
      'number': '123-456',
      'label': 'Mother',
      'initials': 'JD'
    },
    {
      'name': 'John Smith',
      'number': '987-654',
      'label': 'Partner',
      'initials': 'JS'
    },
    {
      'name': 'Dr. Emily Carter',
      'number': '555-0199',
      'label': 'Family Doctor',
      'initials': 'DE'
    },
  ];

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    await FlutterContacts.requestPermission();
  }

  // --- LOGIC: ADD CONTACT ---
  Future<void> _addContact() async {
    if (_emergencyContacts.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Maximum 5 contacts reached."),
        backgroundColor: AppColors.alertRed,
      ));
      return;
    }

    final Contact? contact = await FlutterContacts.openExternalPick();

    if (contact != null && contact.phones.isNotEmpty) {
      String name = contact.displayName;
      String number = contact.phones.first.number;
      String initials = name.isNotEmpty ? name[0].toUpperCase() : "?";
      if (name.contains(" ") && name.split(" ").length > 1) {
        initials =
            name.split(" ").take(2).map((e) => e[0].toUpperCase()).join();
      }

      _showLabelDialog(name, number, initials);
    }
  }

  void _showLabelDialog(String name, String number, String initials) {
    TextEditingController labelController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Relationship Label",
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: labelController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "e.g. Mother, Partner...",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primarySky),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primarySky,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() {
                _emergencyContacts.add({
                  'name': name,
                  'number': number,
                  'label': labelController.text.isEmpty
                      ? "Emergency Contact"
                      : labelController.text,
                  'initials': initials,
                });
              });
              Navigator.pop(context);
            },
            child: const Text("Save",
                style: TextStyle(
                    color: AppColors.background, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _removeContact(int index) {
    setState(() {
      _emergencyContacts.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FIXED: Solid Brand Background (No Gradient)
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Column(
          children: [
            // Header Title
            const Padding(
              padding: EdgeInsets.only(top: 24, bottom: 20),
              child: Text("Emergency Contacts",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ),

            // Scrollable List
            Expanded(
              child: ListView.builder(
                // FIXED: Added massive bottom padding so list items don't hide behind footer
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                itemCount: _emergencyContacts.length,
                itemBuilder: (context, index) {
                  final contact = _emergencyContacts[index];
                  return _buildContactCard(contact, index);
                },
              ),
            ),
          ],
        ),
      ),

      // --- FLOATING ACTION BUTTON ---
      // FIXED: Used 'floatingActionButtonLocation' isn't enough, we use padding to push it up
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        // FIXED: Increased bottom padding to 100 to clear the modern footer
        padding: const EdgeInsets.only(bottom: 100),
        child: SizedBox(
          width: 65,
          height: 65,
          child: FloatingActionButton(
            onPressed: _addContact,
            backgroundColor: AppColors.primarySky,
            elevation: 10,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, size: 32, color: AppColors.background),
          ),
        ),
      ),
    );
  }

  // --- CARD WIDGET ---
  Widget _buildContactCard(Map<String, String> contact, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          // 1. Header: Avatar + Info + Menu
          Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primarySky.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  contact['initials'] ?? "?",
                  style: const TextStyle(
                      color: AppColors.primarySky,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 16),

              // Name & Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact['name']!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact['label']!,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),

              // Menu Icon
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: Colors.white38),
                color: AppColors.surfaceCard,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: const Row(children: [
                      Icon(Icons.delete_outline,
                          color: AppColors.alertRed, size: 20),
                      SizedBox(width: 8),
                      Text("Remove", style: TextStyle(color: Colors.white)),
                    ]),
                    onTap: () => _removeContact(index),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 2. Action Buttons
          Row(
            children: [
              // Call Button
              Expanded(
                child: SizedBox(
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon:
                        const Icon(Icons.phone, size: 18, color: Colors.white),
                    label: const Text("Call"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Alert Button
              Expanded(
                child: SizedBox(
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_active_outlined,
                        size: 20, color: Colors.white),
                    label: const Text("Alert"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.alertRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
}
