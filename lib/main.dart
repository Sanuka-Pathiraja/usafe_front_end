import 'package:flutter/material.dart';

void main() {
  runApp(const USafeApp());
}

class USafeApp extends StatelessWidget {
  const USafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Sky Blue Theme Configuration
        primaryColor: const Color(0xFF29B6F6),
        scaffoldBackgroundColor: const Color(0xFFE0F7FA),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF29B6F6),
          secondary: const Color(0xFF0288D1),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Mock function to simulate selecting a saved account
  void _selectAccount(String email) {
    setState(() {
      _emailController.text = email;
    });
    // Optional: Focus on password field after selection
    FocusScope.of(context).nextFocus();
  }

  // Login Logic
  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      // Simulate API Call
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${_emailController.text}!'),
          backgroundColor: const Color(0xFF29B6F6),
        ),
      );

      // TODO: Navigate to Dashboard
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Dashboard()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Screen dimensions for responsive spacing
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        height: size.height,
        width: double.infinity,
        decoration: const BoxDecoration(
          // Gradient Background: White to Light Sky Blue
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFE0F7FA)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- LOGO SECTION ---
                const Icon(
                  Icons.security_rounded, // Shield Icon
                  size: 60,
                  color: Color(0xFF29B6F6),
                ),
                const SizedBox(height: 10),
                const Text(
                  "USafe",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  "Intelligent. Predictive. Secure.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 30),

                // --- LOGIN CARD ---
                Card(
                  elevation: 8,
                  shadowColor: const Color(0xFF29B6F6).withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Saved Accounts Section
                          const Center(
                            child: Text(
                              "Select an account to continue",
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Mock Account 1
                          _buildAccountSelector(
                            name: "Nimali Perera",
                            email: "nimali@uni.lk",
                            initial: "N",
                            color: const Color(0xFF29B6F6),
                          ),
                          const SizedBox(height: 10),

                          // Mock Account 2
                          _buildAccountSelector(
                            name: "Sandun K.",
                            email: "sandun@work.lk",
                            initial: "S",
                            color: const Color(0xFF2C3E50),
                          ),

                          const SizedBox(height: 25),

                          // Divider
                          Row(
                            children: const [
                              Expanded(child: Divider(color: Colors.black12)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text("OR ENTER DETAILS",
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                              ),
                              Expanded(child: Divider(color: Colors.black12)),
                            ],
                          ),

                          const SizedBox(height: 25),

                          // 2. Email Input
                          TextFormField(
                            controller: _emailController,
                            decoration: _inputDecoration(
                                "Email Address", Icons.email_outlined),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return 'Please enter an email';
                              if (!value.contains('@'))
                                return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          // 3. Password Input
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: _inputDecoration(
                                "Password", Icons.lock_outline),
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return 'Please enter a password';
                              return null;
                            },
                          ),

                          const SizedBox(height: 25),

                          // 4. Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF29B6F6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: const Text(
                                "Sign In",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? ",
                        style: TextStyle(color: Colors.grey)),
                    GestureDetector(
                      onTap: () {},
                      child: const Text("Sign Up",
                          style: TextStyle(
                              color: Color(0xFF29B6F6),
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  // Reusable Input Style
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFFFAFCFD),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEFF4F6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEFF4F6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF29B6F6), width: 2),
      ),
    );
  }

  // Reusable Account Selector Widget
  Widget _buildAccountSelector(
      {required String name,
      required String email,
      required String initial,
      required Color color}) {
    return InkWell(
      onTap: () => _selectAccount(email),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEFF4F6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              radius: 18,
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(email,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Color(0xFF29B6F6)),
          ],
        ),
      ),
    );
  }
}
