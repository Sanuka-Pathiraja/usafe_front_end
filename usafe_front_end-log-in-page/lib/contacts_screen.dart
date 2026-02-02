import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // List to store selected contacts
  // Logic: The order in this list determines the calling sequence
  final List<Map<String, String>> _emergencyContacts = [
    // Example data (Remove these defaults later if you want a clean start)
    {'name': 'Steve', 'number': '+1 555-0100', 'label': 'Brother'},
    {'name': 'Smith', 'number': '+1 555-0102', 'label': 'Neighbor'},
  ];

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    // Asks user for permission to read contacts when page loads
    await FlutterContacts.requestPermission();
  }

  // --- LOGIC: ADD CONTACT ---
  Future<void> _addContact() async {
    // Constraint: Max 5
    if (_emergencyContacts.length >= 5) return;

    // 1. Open Phone Book
    final Contact? contact = await FlutterContacts.openExternalPick();

    if (contact != null && contact.phones.isNotEmpty) {
      String name = contact.displayName;
      String number = contact.phones.first.number;

      // 2. Open Dialog for Custom Label
      _showLabelDialog(name, number);
    } else if (contact != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This contact has no phone number.")),
      );
    }
  }

  void _showLabelDialog(String name, String number) {
    TextEditingController labelController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2436),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Name this Contact",
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Selected: $name",
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 15),
            TextField(
              controller: labelController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "e.g. Mother, Doctor...",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.black12,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF26A69A)),
            onPressed: () {
              setState(() {
                _emergencyContacts.add({
                  'name': name,
                  'number': number,
                  'label': labelController.text.isEmpty
                      ? name
                      : labelController.text,
                });
              });
              Navigator.pop(context);
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- LOGIC: REORDER & REMOVE ---
  void _reorderContacts(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _emergencyContacts.removeAt(oldIndex);
      _emergencyContacts.insert(newIndex, item);
    });
  }

  void _removeContact(int index) {
    setState(() {
      _emergencyContacts.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isMinMet = _emergencyContacts.length >= 3;
    bool isMaxReached = _emergencyContacts.length >= 5;

    return Scaffold(
      backgroundColor: const Color(0xFF151B28),
      appBar: AppBar(
        title: const Text("Priority List",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Status Banner
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isMinMet
                  ? const Color(0xFF26A69A).withOpacity(0.1)
                  : const Color(0xFFE53935).withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: isMinMet
                      ? const Color(0xFF26A69A)
                      : const Color(0xFFE53935).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(isMinMet ? Icons.check_circle : Icons.info,
                    color: isMinMet
                        ? const Color(0xFF26A69A)
                        : const Color(0xFFE53935)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isMinMet
                        ? "System Ready. Contacts will be called in the order below."
                        : "Add ${3 - _emergencyContacts.length} more contacts to enable SOS calls.",
                    style: TextStyle(
                        color: isMinMet
                            ? const Color(0xFF26A69A)
                            : const Color(0xFFE53935),
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // 2. Reorderable List
          Expanded(
            child: Theme(
              data: ThemeData(
                  canvasColor:
                      const Color(0xFF1C2436)), // Drag background color
              child: ReorderableListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                onReorder: _reorderContacts,
                children: [
                  for (int index = 0;
                      index < _emergencyContacts.length;
                      index++)
                    Container(
                      key: ValueKey(
                          _emergencyContacts[index]['number']), // Unique Key
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2436),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF26A69A).withOpacity(0.2),
                          child: Text("${index + 1}",
                              style: const TextStyle(
                                  color: Color(0xFF26A69A),
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                          _emergencyContacts[index]['label']!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        subtitle: Text(
                          "${_emergencyContacts[index]['name']} • ${_emergencyContacts[index]['number']}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Color(0xFFE53935)),
                              onPressed: () => _removeContact(index),
                            ),
                            const Icon(Icons.drag_handle,
                                color: Colors.white24),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. Add Button (Hidden if max reached)
          Padding(
            padding: const EdgeInsets.only(bottom: 100, top: 20),
            child: Opacity(
              opacity: isMaxReached ? 0.5 : 1.0,
              child: ElevatedButton.icon(
                onPressed: isMaxReached ? null : _addContact,
                icon: const Icon(Icons.add),
                label: Text(
                    isMaxReached ? "Limit Reached (5)" : "Add from Contacts"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26A69A),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
