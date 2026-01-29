import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'config.dart';
import 'home_screen.dart';
import 'auth_screens.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  // --- FIX: Removed 'const' from this list to prevent errors ---
  final List<Widget> _pages = [
    HomeScreen(),
    MapScreen(),
    ContactsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: AppColors.surfaceCard,
          selectedItemColor: AppColors.primarySky,
          unselectedItemColor: AppColors.textGrey,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.shield_outlined),
                activeIcon: Icon(Icons.shield),
                label: "Home"),
            BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: "Map"),
            BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: "Contacts"),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: "Profile"),
          ],
        ),
      ),
    );
  }
}

// --- PLACEHOLDER SCREENS (To ensure dashboard compiles) ---
// Note: You will replace MapScreen with the Google Maps code later.

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  Future<void> _addNewContact() async {
    if (await FlutterContacts.requestPermission()) {
      final Contact? contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        setState(() {
          if (!MockDatabase.savedPhoneContacts.any((c) => c.id == contact.id)) {
            MockDatabase.savedPhoneContacts.add(contact);
            MockDatabase.syncContacts();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency Contacts")),
      floatingActionButton: FloatingActionButton(
          onPressed: _addNewContact,
          backgroundColor: AppColors.primarySky,
          child: const Icon(Icons.add, color: Colors.white)),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: MockDatabase.savedPhoneContacts.length,
        itemBuilder: (context, index) {
          final contact = MockDatabase.savedPhoneContacts[index];
          String phone = (contact.phones.isNotEmpty)
              ? contact.phones.first.number
              : "No number";
          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Text(contact.displayName[0],
                      style: const TextStyle(color: AppColors.primarySky))),
              title: Text(contact.displayName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(phone,
                  style: const TextStyle(color: AppColors.textGrey)),
              trailing: IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.textGrey),
                  onPressed: () => setState(() {
                        MockDatabase.savedPhoneContacts.remove(contact);
                        MockDatabase.syncContacts();
                      })),
            ),
          );
        },
      ),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Community Safety Map")),
      body: Center(child: Icon(Icons.map, size: 100, color: Colors.white10)),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Center(child: Icon(Icons.person, size: 100, color: Colors.white10)),
    );
  }
}
