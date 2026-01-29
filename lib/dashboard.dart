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
    HomeScreen(),
    const MapScreen(),
    const ContactsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.surfaceCard,
        selectedItemColor: AppColors.primarySky,
        unselectedItemColor: AppColors.textGrey,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.shield), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Map"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Contacts"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

// --- STATIC MAP SCREEN (No API Key Required) ---
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Community Safety Map")),
      body: Stack(
        children: [
          Container(color: const Color(0xFF1B262C)), // Dark Map Background
          const Center(
              child: Icon(Icons.map, size: 100, color: Colors.white10)),

          // Static Zone Markers (Visual Only)
          Positioned(
              top: 150,
              left: 80,
              child: _buildZoneMarker(AppColors.dangerRed, "High Risk")),
          Positioned(
              top: 300,
              right: 60,
              child: _buildZoneMarker(AppColors.accentTeal, "Safe Zone")),

          // Legend
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

// --- REAL CONTACTS SCREEN ---
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
          MockDatabase.savedPhoneContacts.add(contact);
          MockDatabase.syncContacts();
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
          child: const Icon(Icons.add)),
      body: ListView.builder(
        itemCount: MockDatabase.savedPhoneContacts.length,
        itemBuilder: (context, index) {
          final c = MockDatabase.savedPhoneContacts[index];
          return ListTile(
            leading: CircleAvatar(child: Text(c.displayName[0])),
            title: Text(c.displayName,
                style: const TextStyle(color: Colors.white)),
            subtitle: Text(
                c.phones.isNotEmpty ? c.phones.first.number : "No Num",
                style: const TextStyle(color: Colors.grey)),
          );
        },
      ),
    );
  }
}

// --- PROFILE SCREEN ---
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Center(
          child: ElevatedButton(
              onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: const Text("Log Out"))),
    );
  }
}
