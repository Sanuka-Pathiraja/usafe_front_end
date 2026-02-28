import 'package:flutter/material.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int selectedIndex = -1;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF05070F),
              Color(0xFF0B1020),
              Color(0xFF05070F),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// BACK BUTTON (CLICKABLE)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Text(
                    "Community Reports",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// ISSUE CARDS
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    IssueCard(
                      icon: Icons.construction,
                      text: "Road Issue",
                      selected: selectedIndex == 0,
                      onTap: () => setState(() => selectedIndex = 0),
                    ),
                    IssueCard(
                      icon: Icons.lightbulb,
                      text: "Street lighting\nIssue",
                      selected: selectedIndex == 1,
                      onTap: () => setState(() => selectedIndex = 1),
                    ),
                    IssueCard(
                      icon: Icons.visibility,
                      text: "Suspicious\nActivity",
                      selected: selectedIndex == 2,
                      onTap: () => setState(() => selectedIndex = 2),
                    ),
                    IssueCard(
                      icon: Icons.groups,
                      text: "Harassments",
                      selected: selectedIndex == 3,
                      onTap: () => setState(() => selectedIndex = 3),
                    ),
                    IssueCard(
                      icon: Icons.apartment,
                      text: "Infrastructure\nIssues",
                      selected: selectedIndex == 4,
                      onTap: () => setState(() => selectedIndex = 4),
                    ),
                    IssueCard(
                      icon: Icons.security,
                      text: "Theft\nSecurity Issue",
                      selected: selectedIndex == 5,
                      onTap: () => setState(() => selectedIndex = 5),
                    ),
                    IssueCard(
                      icon: Icons.water_damage,
                      text: "Environmental\nIssue",
                      selected: selectedIndex == 6,
                      onTap: () => setState(() => selectedIndex = 6),
                    ),
                    IssueCard(
                      icon: Icons.camera_alt,
                      text: "Vandalism\nProperty Issue",
                      selected: selectedIndex == 7,
                      onTap: () => setState(() => selectedIndex = 7),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                "Describe the issue",
                style: TextStyle(color: Colors.white),
              ),

              const SizedBox(height: 8),

              TextField(
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Your example text here...",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              /// PHOTO BUTTONS (CLICKABLE)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showMessage("Camera option clicked");
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Take Photo"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showMessage("Gallery option clicked");
                      },
                      icon: const Icon(Icons.image),
                      label: const Text("From Gallery"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// SUBMIT BUTTON (CLICKABLE + VALIDATION)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedIndex == -1) {
                      showMessage("Please select an issue type");
                    } else {
                      showMessage("Community report submitted successfully");
                    }
                  },
                  child: const Text("Submit Community Report"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IssueCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const IssueCard({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Colors.white24 : Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.green : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            if (selected)
              const Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.green,
                  child: Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}