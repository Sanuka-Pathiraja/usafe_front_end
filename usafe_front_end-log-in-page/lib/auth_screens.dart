import 'package:flutter/material.dart';
import 'dart:async';
import 'config.dart';
import 'dashboard.dart';

// --- SPLASH SCREEN ---
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
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // Navigate to Login after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/usafe_logo.png',
                  height: 140,
                  errorBuilder: (c, e, s) => const Icon(Icons.shield,
                      size: 80, color: AppColors.primarySky)),
              const SizedBox(height: 20),
              const Text("USafe",
                  style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- LOGIN SCREEN ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleLogin() {
    if (MockDatabase.validateLogin(
        _emailController.text.trim(), _passwordController.text.trim())) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Please enter an email and password."),
        backgroundColor: AppColors.dangerRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Image.asset('assets/usafe_logo.png',
                      height: 100,
                      errorBuilder: (c, e, s) => const Icon(Icons.shield,
                          size: 80, color: AppColors.primarySky)),
                ),
                const SizedBox(height: 30),
                const Text("Welcome Back!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 8),
                const Text("Please sign in to continue",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: AppColors.textGrey)),
                const SizedBox(height: 50),

                // Modern Input Fields
                _buildModernInput(
                    _emailController, "Email", Icons.email_outlined),
                const SizedBox(height: 20),
                _buildModernInput(
                    _passwordController, "Password", Icons.lock_outline,
                    isPassword: true),

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
                // Gradient Login Button
                Container(
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
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
                              letterSpacing: 1.2))),
                ),

                const SizedBox(height: 40),
                const Row(children: [
                  Expanded(child: Divider(color: Colors.white24)),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("Or continue with",
                          style: TextStyle(color: AppColors.textGrey))),
                  Expanded(child: Divider(color: Colors.white24))
                ]),
                const SizedBox(height: 30),

                // Google Button
                SizedBox(
                  height: 55,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
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
    );
  }

  Widget _buildModernInput(
      TextEditingController controller, String label, IconData icon,
      {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

// --- SIGNUP SCREEN ---
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Create Account"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Text("Join USafe today",
                style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
            const SizedBox(height: 40),
            _buildModernInput(emailCtrl, "Email", Icons.email_outlined),
            const SizedBox(height: 20),
            _buildModernInput(passCtrl, "Password", Icons.lock_outline,
                isPassword: true),
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
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
                        borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  if (emailCtrl.text.isNotEmpty && passCtrl.text.isNotEmpty) {
                    MockDatabase.registerUser(emailCtrl.text, passCtrl.text);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Account Created! You can Login now."),
                        behavior: SnackBarBehavior.floating));
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
    );
  }

  Widget _buildModernInput(
      TextEditingController controller, String label, IconData icon,
      {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16)),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: AppColors.textGrey),
            prefixIcon: Icon(icon, color: AppColors.primarySky),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
      ),
    );
  }
}

// --- FORGOT PASSWORD SCREEN ---
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Reset Password"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.lock_reset, size: 80, color: AppColors.primarySky),
            const SizedBox(height: 20),
            const Text(
                "Enter your email and we'll send you a link to get back into your account.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textGrey, fontSize: 16, height: 1.5)),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16)),
              child: TextFormField(
                decoration: const InputDecoration(
                    labelText: "Email",
                    labelStyle: TextStyle(color: AppColors.textGrey),
                    prefixIcon:
                        Icon(Icons.email_outlined, color: AppColors.primarySky),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16)),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Reset Link Sent!"),
                      behavior: SnackBarBehavior.floating));
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
    );
  }
}
