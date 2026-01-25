import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_contacts/flutter_contacts.dart'; // REQUIRED PACKAGE

void main() {
  runApp(const USafeApp());
}

// ----------------------------------------
// 1. MOCK DATABASE & THEME
// ----------------------------------------
class MockDatabase {
  static final List<Map<String, String>> _users = [
    {'name': 'Nimali Perera', 'email': 'nimali@uni.lk', 'password': '123'},
  ];
  // Storage for selected emergency contacts
  static List<Contact> savedContacts = [];

  static bool validateLogin(String email, String password) =>
      _users.any((u) => u['email'] == email && u['password'] == password);

  static void registerUser(String name, String email, String password) =>
      _users.add({'name': name, 'email': email, 'password': password});
}

class AppColors {
  static const Color background = Color(0xFF05111A);
  static const Color accentTeal = Color(0xFF1DE9B6);
  static const Color dangerRed = Color(0xFFFF3D00);
  static const Color surface = Color(0xFF102027);
  static const Color cardBlue =
      Color(0xFF1C2A35); // Slightly lighter for contact cards
}

class USafeApp extends StatelessWidget {
  const USafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'USafe',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.accentTeal,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ----------------------------------------
// 2. LOGIN SCREEN (Fixed: Now includes Sign Up)
// ----------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      if (MockDatabase.validateLogin(
          _emailController.text.trim(), _passwordController.text.trim())) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => DashboardScreen()));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invalid Credentials')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset('assets/usafe_logo.png',
                  height: 120,
                  errorBuilder: (c, e, s) => const Icon(Icons.shield,
                      size: 100, color: AppColors.accentTeal)),
              const SizedBox(height: 40),

              // Login Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20)),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDeco("Email", Icons.email),
                          validator: (v) => v!.isEmpty ? "Required" : null),
                      const SizedBox(height: 15),
                      TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDeco("Password", Icons.lock),
                          validator: (v) => v!.isEmpty ? "Required" : null),
                      const SizedBox(height: 25),
                      SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                              onPressed: _handleLogin,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentTeal,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30))),
                              child: const Text("Sign In",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- THIS WAS MISSING ---
              TextButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SignupScreen()));
                },
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(color: Colors.grey),
                    children: [
                      TextSpan(text: "Don't have an account? NMafgff"),
                      TextSpan(
                          text: "Sign Up",
                          style: TextStyle(
                              color: AppColors.accentTeal,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              // ------------------------
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: AppColors.accentTeal),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accentTeal)));
}

// Ensure the SignupScreen class exists in your file too!
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final name = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();

    return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Create Account",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Join USafe today.",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              _buildField(name, "Full Name", Icons.person),
              const SizedBox(height: 15),
              _buildField(email, "Email", Icons.email),
              const SizedBox(height: 15),
              _buildField(pass, "Password", Icons.lock, isPass: true),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentTeal,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30))),
                    onPressed: () {
                      MockDatabase.registerUser(
                          name.text, email.text, pass.text);
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => DashboardScreen()));
                    },
                    child: const Text("Register",
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold))),
              )
            ],
          ),
        ));
  }

  Widget _buildField(
      TextEditingController controller, String label, IconData icon,
      {bool isPass = false}) {
    return TextField(
        controller: controller,
        obscureText: isPass,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.grey),
            prefixIcon: Icon(icon, color: AppColors.accentTeal),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white10)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accentTeal))));
  }
}

// ----------------------------------------
// 3. MAIN DASHBOARD (Updated with Navigation)
// ----------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; // 0=Home, 1=Contacts

  final List<Widget> _pages = [
    const HomeScreen(), // The SOS Button Page
    const ContactsScreen(), // The NEW Contacts Page
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.accentTeal,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Contacts"),
        ],
      ),
    );
  }
}

// ----------------------------------------
// 4. HOME SCREEN (SOS Button - Unchanged Logic)
// ----------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isPanicMode = false;
  bool _isHolding = false;
  double _holdProgress = 0.0;
  Timer? _holdTimer;
  int _countdownSeconds = 180;
  Timer? _countdownTimer;

  void _startHolding() {
    if (_isPanicMode) return;
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });
    _holdTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      setState(() {
        _holdProgress += 0.015;
        if (_holdProgress >= 1.0) _triggerPanicMode();
      });
    });
  }

  void _stopHolding() {
    if (_isPanicMode) return;
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  void _triggerPanicMode() {
    _holdTimer?.cancel();
    setState(() {
      _isPanicMode = true;
      _holdProgress = 0.0;
      _countdownSeconds = 179;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: _isPanicMode ? _buildPanicUI() : _buildSafeUI(),
      ),
    );
  }

  Widget _buildSafeUI() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.accentTeal, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            const Text("Your Area: Safe",
                style: TextStyle(color: Colors.white)),
          ]),
        ),
        const Spacer(),
        GestureDetector(
          onTapDown: (_) => _startHolding(),
          onTapUp: (_) => _stopHolding(),
          onTapCancel: () => _stopHolding(),
          child: Stack(alignment: Alignment.center, children: [
            Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentTeal
                        .withOpacity(_isHolding ? 0.1 : 0.05))),
            CustomPaint(
                size: const Size(220, 220),
                painter: RingPainter(
                    progress: _holdProgress, color: AppColors.accentTeal)),
            const Text("Hold to Activate SOS...",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildPanicUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("SOS ACTIVATED",
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        Stack(alignment: Alignment.center, children: [
          CustomPaint(
              size: const Size(220, 220),
              painter: RingPainter(
                  progress: _countdownSeconds / 180,
                  color: AppColors.dangerRed,
                  isFullRing: true)),
          Text(
              "${(_countdownSeconds / 60).floor()}:${(_countdownSeconds % 60).toString().padLeft(2, '0')}",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 40),
        SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton(
                onPressed: () {
                  _countdownTimer?.cancel();
                  setState(() => _isPanicMode = false);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal),
                child: const Text("Cancel SOS",
                    style: TextStyle(color: Colors.black)))),
      ],
    );
  }
}

// ----------------------------------------
// 5. NEW CONTACTS SCREEN (With Phone Integration)
// ----------------------------------------
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    // Usually you'd load saved contacts here
  }

  Future<void> _addNewContact() async {
    // 1. Request Permission
    if (await FlutterContacts.requestPermission()) {
      // 2. Open Phone Contact Picker
      final Contact? contact = await FlutterContacts.openExternalPick();

      if (contact != null) {
        setState(() {
          // Prevent Duplicates
          if (!MockDatabase.savedContacts.any((c) => c.id == contact.id)) {
            // Check limit (Max 5)
            if (MockDatabase.savedContacts.length < 5) {
              MockDatabase.savedContacts.add(contact);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Maximum 5 contacts allowed.")));
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Contact already added.")));
          }
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Permission Denied. Please enable contacts access.")));
    }
  }

  void _removeContact(Contact contact) {
    setState(() {
      MockDatabase.savedContacts.remove(contact);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Emergency Contacts"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: MockDatabase.savedContacts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.contact_phone_outlined,
                      size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 20),
                  const Text("No contacts added yet.",
                      style: TextStyle(color: Colors.grey)),
                  const Text("Add 3-5 trusted contacts.",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: MockDatabase.savedContacts.length,
              itemBuilder: (context, index) {
                final contact = MockDatabase.savedContacts[index];
                // Try to get the first phone number, or show placeholder
                String phone = (contact.phones.isNotEmpty)
                    ? contact.phones.first.number
                    : "No number";

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Header Row: Avatar + Name + Menu
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: (contact.photo != null)
                                ? MemoryImage(contact.photo!)
                                : null,
                            backgroundColor: Colors.grey[700],
                            child: (contact.photo == null)
                                ? Text(contact.displayName[0],
                                    style: const TextStyle(color: Colors.white))
                                : null,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(contact.displayName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Text(phone,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.more_vert, color: Colors.grey),
                            onPressed: () => _removeContact(
                                contact), // Simple delete for now
                          )
                        ],
                      ),
                      const SizedBox(height: 15),
                      // Button Row: Call + Alert
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {/* Call Logic */},
                              icon: const Icon(Icons.call, size: 18),
                              label: const Text("Call"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C3E50),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {/* Alert Logic */},
                              icon: const Icon(Icons.warning_amber_rounded,
                                  size: 18),
                              label: const Text("Alert"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.dangerRed,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewContact,
        backgroundColor: AppColors.accentTeal,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

// ----------------------------------------
// 6. RING PAINTER (For SOS Animation)
// ----------------------------------------
class RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isFullRing;
  RingPainter(
      {required this.progress, required this.color, this.isFullRing = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 12.0;

    // Background Track
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white10
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth);

    // Progress Arc
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        isFullRing ? 2 * math.pi : sweepAngle,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth);
  }

  @override
  bool shouldRepaint(covariant RingPainter old) => old.progress != progress;
}
