import 'package:flutter/material.dart';
import 'dart:async'; // For Timer logic (Splash screen delay)
import 'config.dart'; // Brand colors (AppColors) & Mock Database
import 'home_screen.dart'; // Target screen after successful login

/// ---------------------------------------------------------------------------
/// AUTHENTICATION FLOW
///
/// This file contains all screens related to user onboarding and access:
/// 1. SplashScreen: Brand logo animation on app launch.
/// 2. LoginScreen: Email/Password entry.
/// 3. SignupScreen: Account creation.
/// 4. ForgotPasswordScreen: Password reset flow.
/// ---------------------------------------------------------------------------

// --- HELPER: BACKGROUND GRADIENT ---
// Ensures a consistent visual theme across all auth screens.
BoxDecoration _buildBackgroundGradient() {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.background, // Deep Matte Midnight
        Color(0xFF0F1218), // Fades to near-black
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// 1. SPLASH SCREEN
// ---------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup Fade Animation (1.5 seconds)
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    // Start Animation
    _controller.forward();

    // Timer: Navigate to Login Screen after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // Cleanup animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with Glow Effect
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primarySky.withOpacity(0.1),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primarySky.withOpacity(0.2),
                            blurRadius: 40,
                            spreadRadius: 5)
                      ]),
                  child: Image.asset(
                    'assets/usafe_logo.png',
                    height: 120,
                    errorBuilder: (c, e, s) => const Icon(Icons.shield,
                        size: 100, color: AppColors.primarySky),
                  ),
                ),
                const SizedBox(height: 30),

                // App Name
                const Text(
                  "USafe",
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),

                // Tagline
                const Text(
                  "Intelligent Personal Safety",
                  style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 14,
                      letterSpacing: 1.0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. LOGIN SCREEN
// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Input Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Logic: Verify credentials against MockDatabase
  void _handleLogin() {
    if (MockDatabase.validateLogin(
        _emailController.text.trim(), _passwordController.text.trim())) {
      // Success: Go to Home
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      // Failure: Show Error SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter an email and password."),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Header Logo
                  Center(
                    child: Image.asset(
                      'assets/usafe_logo.png',
                      height: 90,
                      errorBuilder: (c, e, s) => const Icon(Icons.shield,
                          size: 80, color: AppColors.primarySky),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Welcome Text
                  const Text("Welcome Back!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text("Please sign in to continue",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, color: AppColors.textGrey)),
                  const SizedBox(height: 50),

                  // Input Fields
                  _buildModernInput(
                      _emailController, "Email", Icons.email_outlined),
                  const SizedBox(height: 20),
                  _buildModernInput(
                      _passwordController, "Password", Icons.lock_outline,
                      isPassword: true),

                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen())),
                      child: const Text("Forgot Password?",
                          style: TextStyle(
                              color: AppColors.primarySky,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Main Action Button (Gradient)
                  Container(
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        AppColors.primarySky,
                        AppColors.primaryNavy
                      ]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primarySky.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _handleLogin,
                      child: const Text("LOGIN",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Divider
                  const Row(children: [
                    Expanded(child: Divider(color: Colors.white12)),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text("Or continue with",
                            style: TextStyle(color: AppColors.textGrey))),
                    Expanded(child: Divider(color: Colors.white12))
                  ]),
                  const SizedBox(height: 30),

                  // Social Login (Google)
                  SizedBox(
                    height: 55,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        backgroundColor: AppColors.surfaceCard.withOpacity(0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/google.jpg',
                              height: 24,
                              errorBuilder: (c, e, s) => const Icon(
                                  Icons.g_mobiledata,
                                  color: Colors.white,
                                  size: 28)),
                          const SizedBox(width: 12),
                          const Text("Google",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Signup Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? ",
                          style: TextStyle(color: AppColors.textGrey)),
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignupScreen())),
                        child: const Text("Sign Up",
                            style: TextStyle(
                                color: AppColors.primarySky,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget for consistent Input Fields
  Widget _buildModernInput(
      TextEditingController controller, String label, IconData icon,
      {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textGrey),
          prefixIcon: Icon(icon, color: AppColors.primarySky),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primarySky),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. SIGNUP SCREEN
// ---------------------------------------------------------------------------
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    return Scaffold(
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // Header (Back Button + Title)
                Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text("Create Account",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 40),
                const Text("Join USafe today",
                    style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
                const SizedBox(height: 40),

                // Form Fields
                _buildModernInput(emailCtrl, "Email", Icons.email_outlined),
                const SizedBox(height: 20),
                _buildModernInput(passCtrl, "Password", Icons.lock_outline,
                    isPassword: true),
                const SizedBox(height: 40),

                // Create Account Button
                Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primarySky, AppColors.primaryNavy]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primarySky.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      if (emailCtrl.text.isNotEmpty &&
                          passCtrl.text.isNotEmpty) {
                        // Register user in mock DB
                        MockDatabase.registerUser(
                            emailCtrl.text, passCtrl.text);
                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("Account Created! You can Login now."),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.safetyTeal));
                        Navigator.pop(context);
                      }
                    },
                    child: const Text("CREATE ACCOUNT",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Reusing the same input style
  Widget _buildModernInput(
      TextEditingController controller, String label, IconData icon,
      {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textGrey),
          prefixIcon: Icon(icon, color: AppColors.primarySky),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primarySky),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. FORGOT PASSWORD SCREEN
// ---------------------------------------------------------------------------
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text("Reset Password",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 60),

                // Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primarySky.withOpacity(0.1)),
                  child: const Icon(Icons.lock_reset,
                      size: 60, color: AppColors.primarySky),
                ),
                const SizedBox(height: 20),

                // Instructions
                const Text(
                  "Enter your email and we'll send you a link to get back into your account.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textGrey, fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 40),

                // Email Input
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: TextFormField(
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Email",
                      labelStyle: TextStyle(color: AppColors.textGrey),
                      prefixIcon: Icon(Icons.email_outlined,
                          color: AppColors.primarySky),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Send Link Button
                Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primarySky, AppColors.primaryNavy]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primarySky.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Reset Link Sent!"),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppColors.safetyTeal));
                      Navigator.pop(context);
                    },
                    child: const Text("SEND RESET LINK",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
