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
  final List<Widget> _pages = [
    const HomeScreen(),
    const MapScreen(),
    const ContactsScreen(),
    const ProfileScreen()
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

// --- CONTACTS SCREEN ---
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

// --- MAP SCREEN ---
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Community Safety Map")),
      body: Stack(
        children: [
          Container(color: const Color(0xFF1B262C)),
          const Center(
              child: Icon(Icons.map, size: 100, color: Colors.white10)),
          Positioned(
              top: 150,
              left: 80,
              child: _buildZoneMarker(AppColors.dangerRed, "High Risk")),
          Positioned(
              top: 300,
              right: 60,
              child: _buildZoneMarker(AppColors.accentTeal, "Safe Zone")),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(AppColors.accentTeal, "Safe"),
                  _buildLegendItem(AppColors.warningOrange, "Caution"),
                  _buildLegendItem(AppColors.dangerRed, "Danger"),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildZoneMarker(Color color, String label) => Column(children: [
        Icon(Icons.location_on, color: color, size: 40),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold))
      ]);
  Widget _buildLegendItem(Color color, String label) => Row(children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: AppColors.textWhite, fontSize: 12))
      ]);
}

// --- PROFILE SCREEN ---
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile & Settings")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
              child: CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.surfaceCard,
                  child: Icon(Icons.person,
                      size: 50, color: AppColors.primarySky))),
          const SizedBox(height: 10),
          const Center(
              child: Text("Nimali Perera",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite))),
          const SizedBox(height: 30),
          _buildSection("Smart Protection"),
          _buildToggle("AI Sound Detection", true),
          _buildToggle("Smart Geofencing", true),
          const SizedBox(height: 20),
          _buildSection("Account"),
          ListTile(
              leading: const Icon(Icons.logout, color: AppColors.dangerRed),
              title: const Text("Log Out",
                  style: TextStyle(color: AppColors.dangerRed)),
              onTap: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false)),
        ],
      ),
    );
  }

  Widget _buildSection(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: const TextStyle(
              color: AppColors.primarySky, fontWeight: FontWeight.bold)));
  Widget _buildToggle(String title, bool val) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
          activeColor: AppColors.primarySky,
          title:
              Text(title, style: const TextStyle(color: AppColors.textWhite)),
          value: val,
          onChanged: (v) {}));
}
