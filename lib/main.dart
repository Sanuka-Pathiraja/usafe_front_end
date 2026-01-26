import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_contacts/flutter_contacts.dart';

void main() {
  runApp(const USafeApp());
}

// ----------------------------------------
// 1. CONFIGURATION & COLORS
// ----------------------------------------
class MockDatabase {
  static final List<Map<String, String>> _users = [
    {'name': 'User', 'email': 'user@usafe.com', 'password': '123'},
  ];
  static List<Contact> savedContacts = [];

  static bool validateLogin(String email, String password) =>
      _users.any((u) => u['email'] == email && u['password'] == password);

  static void registerUser(String name, String email, String password) =>
      _users.add({'name': name, 'email': email, 'password': password});
}

class AppColors {
  // --- CORE PALETTE ---
  static const Color primarySky = Color(0xFF00B0FF); // Bright Sky Blue
  static const Color primaryNavy =
      Color(0xFF01579B); // Deep Navy Blue (Text/Accents)
  static const Color background =
      Color(0xFFF0F8FF); // "Alice Blue" (Very pale white-blue)
  static const Color surfaceWhite = Colors.white; // Pure White

  // --- FUNCTIONAL COLORS ---
  static const Color dangerRed = Color(0xFFFF3D00); // Panic Red
  static const Color successGreen = Color(0xFF00E676); // Safe Green
  static const Color textDark = Color(0xFF01579B); // Navy for main text
  static const Color textLight =
      Color(0xFF546E7A); // Blue-Grey for secondary text
}

class USafeApp extends StatelessWidget {
  const USafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'USafe',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primarySky,
        useMaterial3: true,
        fontFamily: 'Roboto',

        // App Bar Styling
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.primaryNavy),
          titleTextStyle: TextStyle(
              color: AppColors.primaryNavy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5),
        ),

        // Text Styling Default
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.textDark),
          bodyMedium: TextStyle(color: AppColors.textDark),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ----------------------------------------
// 2. LOGIN SCREEN (Updated)
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
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Invalid Credentials'),
            backgroundColor: AppColors.dangerRed));
      }
    }
  }

  void _handleForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset password link sent to email')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceWhite,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- LOGO SECTION ---
              Container(
                height: 140,
                width: 140,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primarySky.withOpacity(0.2), width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primarySky.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5)
                    ]),
                child: Image.asset(
                  'assets/usafe_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.shield_rounded,
                        size: 60, color: AppColors.primarySky);
                  },
                ),
              ),

              const SizedBox(height: 25),
              const Text("USafe",
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryNavy,
                      letterSpacing: -1)),
              const Text("Secure. Protected. Connected.",
                  style: TextStyle(color: AppColors.textLight, fontSize: 16)),
              const SizedBox(height: 40),

              // --- FORM ---
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                        _emailController, "Email", Icons.email_outlined),
                    const SizedBox(height: 16),
                    _buildTextField(
                        _passwordController, "Password", Icons.lock_outline,
                        isPass: true),

                    // --- FORGOT PASSWORD BUTTON ---
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _handleForgotPassword,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text("Forgot Password?",
                            style: TextStyle(
                                color: AppColors.primarySky,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primarySky,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: AppColors.primarySky.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("LOG IN",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Divider
              Row(children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child:
                        Text("OR", style: TextStyle(color: Colors.grey[400]))),
                Expanded(child: Divider(color: Colors.grey[300])),
              ]),

              const SizedBox(height: 25),

              // --- GOOGLE SIGN IN (With google.jpg) ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () {/* Google Logic */},
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Loading the google.jpg image
                      Image.asset(
                        'assets/google.jpg',
                        height: 24,
                        width: 24,
                        errorBuilder: (c, e, s) =>
                            const Icon(Icons.g_mobiledata, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      const Text("Continue with Google",
                          style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Sign Up Link
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SignupScreen())),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(color: AppColors.textLight, fontSize: 15),
                    children: [
                      TextSpan(text: "New here? "),
                      TextSpan(
                          text: "Create Account",
                          style: TextStyle(
                              color: AppColors.primarySky,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController c, String label, IconData icon,
      {bool isPass = false}) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.white, width: 2), // White border for clean look
          boxShadow: [
            BoxShadow(
                color: AppColors.primarySky.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: TextFormField(
        controller: c,
        obscureText: isPass,
        style: const TextStyle(
            color: AppColors.primaryNavy, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textLight.withOpacity(0.7)),
          prefixIcon: Icon(icon, color: AppColors.primarySky),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: (v) => v!.isEmpty ? "Required" : null,
      ),
    );
  }
}

// ----------------------------------------
// 3. SIGNUP SCREEN
// ----------------------------------------
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final name = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();

    return Scaffold(
        backgroundColor: AppColors.surfaceWhite,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Create Account",
                  style: TextStyle(
                      color: AppColors.primaryNavy,
                      fontSize: 32,
                      fontWeight: FontWeight.w900)),
              const Text("Join the USafe community.",
                  style: TextStyle(color: AppColors.textLight)),
              const SizedBox(height: 40),
              _buildField(name, "Full Name", Icons.person_outline),
              const SizedBox(height: 20),
              _buildField(email, "Email", Icons.email_outlined),
              const SizedBox(height: 20),
              _buildField(pass, "Password", Icons.lock_outline, isPass: true),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primarySky,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    onPressed: () {
                      MockDatabase.registerUser(
                          name.text, email.text, pass.text);
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DashboardScreen()));
                    },
                    child: const Text("REGISTER",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1))),
              )
            ],
          ),
        ));
  }

  Widget _buildField(TextEditingController c, String label, IconData icon,
      {bool isPass = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: c,
        obscureText: isPass,
        style: const TextStyle(color: AppColors.textDark),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textLight),
          prefixIcon: Icon(icon, color: AppColors.primarySky),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

// ----------------------------------------
// 4. MAIN DASHBOARD
// ----------------------------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const HomeScreen(),
    const ContactsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
              color: AppColors.primaryNavy.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ]),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primarySky,
          unselectedItemColor: Colors.grey[400],
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.shield_outlined),
                activeIcon: Icon(Icons.shield),
                label: "SOS"),
            BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: "Contacts"),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------
// 5. HOME SCREEN (SOS UI)
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: _isPanicMode ? _buildPanicUI() : _buildSafeUI(),
        ),
      ),
    );
  }

  Widget _buildSafeUI() {
    return Column(
      children: [
        const SizedBox(height: 20),
        // --- STATUS PILL ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primarySky.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5))
              ]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.successGreen, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            const Text("Status: Safe",
                style: TextStyle(
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ]),
        ),

        const Spacer(),

        // --- SOS BUTTON ---
        GestureDetector(
          onTapDown: (_) => _startHolding(),
          onTapUp: (_) => _stopHolding(),
          onTapCancel: () => _stopHolding(),
          child: Stack(alignment: Alignment.center, children: [
            // Outer Ring
            CustomPaint(
                size: const Size(260, 260),
                painter: RingPainter(
                    progress: _holdProgress,
                    color: AppColors.primarySky,
                    trackColor: AppColors.primarySky.withOpacity(0.1))),
            // Inner Circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Sky Blue dominant gradient
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isHolding
                        ? [AppColors.primaryNavy, AppColors.primarySky]
                        : [AppColors.primarySky, Color(0xFF40C4FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primarySky.withOpacity(0.5),
                        blurRadius: _isHolding ? 30 : 20,
                        offset: const Offset(0, 10))
                  ]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app,
                      color: Colors.white, size: _isHolding ? 55 : 50),
                  const SizedBox(height: 10),
                  Text(_isHolding ? "HOLDING..." : "HOLD FOR SOS",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ]),
        ),
        const Spacer(),
        const Text("Press and hold for 3 seconds",
            style: TextStyle(color: AppColors.textLight)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPanicUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
              color: AppColors.dangerRed.withOpacity(0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.warning_rounded,
              size: 70, color: AppColors.dangerRed),
        ),
        const SizedBox(height: 30),
        const Text("SOS ACTIVATED",
            style: TextStyle(
                color: AppColors.dangerRed,
                fontSize: 28,
                fontWeight: FontWeight.w900)),
        const Text("Sending alert to contacts...",
            style: TextStyle(color: AppColors.textLight)),
        const SizedBox(height: 30),
        Stack(alignment: Alignment.center, children: [
          CustomPaint(
              size: const Size(220, 220),
              painter: RingPainter(
                  progress: _countdownSeconds / 180,
                  color: AppColors.dangerRed,
                  trackColor: AppColors.dangerRed.withOpacity(0.1),
                  isFullRing: true)),
          Text(
              "${(_countdownSeconds / 60).floor()}:${(_countdownSeconds % 60).toString().padLeft(2, '0')}",
              style: const TextStyle(
                  color: AppColors.primaryNavy,
                  fontSize: 50,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 50),
        SizedBox(
            width: 200,
            height: 50,
            child: OutlinedButton(
                onPressed: () {
                  _countdownTimer?.cancel();
                  setState(() => _isPanicMode = false);
                },
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.primaryNavy, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30))),
                child: const Text("CANCEL SOS",
                    style: TextStyle(
                        color: AppColors.primaryNavy,
                        fontWeight: FontWeight.bold)))),
      ],
    );
  }
}

// ----------------------------------------
// 6. CONTACTS SCREEN
// ----------------------------------------
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
          if (!MockDatabase.savedContacts.any((c) => c.id == contact.id)) {
            if (MockDatabase.savedContacts.length < 5) {
              MockDatabase.savedContacts.add(contact);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Maximum 5 contacts allowed.")));
            }
          }
        });
      }
    }
  }

  void _removeContact(Contact contact) {
    setState(() => MockDatabase.savedContacts.remove(contact));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Emergency Contacts")),
      body: MockDatabase.savedContacts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primarySky.withOpacity(0.1),
                              blurRadius: 20)
                        ]),
                    child: const Icon(Icons.person_add_alt_1_rounded,
                        size: 60, color: AppColors.primarySky),
                  ),
                  const SizedBox(height: 20),
                  const Text("No contacts yet",
                      style: TextStyle(
                          color: AppColors.primaryNavy,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: MockDatabase.savedContacts.length,
              itemBuilder: (context, index) {
                final contact = MockDatabase.savedContacts[index];
                String phone = (contact.phones.isNotEmpty)
                    ? contact.phones.first.number
                    : "No number";

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ]),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: AppColors.background,
                            child: Text(contact.displayName[0],
                                style: const TextStyle(
                                    color: AppColors.primarySky,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20)),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(contact.displayName,
                                    style: const TextStyle(
                                        color: AppColors.primaryNavy,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                Text(phone,
                                    style: const TextStyle(
                                        color: AppColors.textLight,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.grey),
                            onPressed: () => _removeContact(contact),
                          )
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewContact,
        backgroundColor: AppColors.primarySky,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ----------------------------------------
// 7. RING PAINTER
// ----------------------------------------
class RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final bool isFullRing;
  RingPainter(
      {required this.progress,
      required this.color,
      required this.trackColor,
      this.isFullRing = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 10.0;

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth);

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
