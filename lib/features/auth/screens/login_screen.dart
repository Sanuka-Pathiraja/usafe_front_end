import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/src/pages/home_screen.dart';

// --- 1. THEME GRADIENT ---
BoxDecoration _buildBackgroundGradient() {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.background, AppColors.backgroundBlack],
    ),
  );
}

// --- 2. SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Timer(const Duration(seconds: 3), () async {
      final prefs = await SharedPreferences.getInstance();
      final bool authorized = prefs.getBool('authorization_seen') ?? false;
      // First-time users must accept the contacts authorization screen.
      if (!authorized) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AuthorizationScreen()),
          );
        }
        return;
      }

      if (MockDatabase.currentUser != null) {
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
      }
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: _buildBackgroundGradient(),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primarySky.withOpacity(0.1),
                      boxShadow: [BoxShadow(color: AppColors.primarySky.withOpacity(0.2), blurRadius: 40, spreadRadius: 5)]
                  ),
                  child: Image.asset('assets/usafe_logo.png', height: 120, errorBuilder: (c, e, s) => const Icon(Icons.shield, size: 100, color: AppColors.primarySky)),
                ),
                const SizedBox(height: 30),
                const Text("USafe", style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: Colors.white)),
                const SizedBox(height: 10),
                const Text("Intelligent Personal Safety", style: TextStyle(color: AppColors.textGrey, fontSize: 14, letterSpacing: 1.0)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- 3. AUTHORIZATION SCREEN ---
class AuthorizationScreen extends StatelessWidget {
  const AuthorizationScreen({super.key});

  Future<void> _handleContinue(BuildContext context) async {
    // Request contacts permission and mark the step as completed.
    await FlutterContacts.requestPermission();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('authorization_seen', true);

    if (!context.mounted) return;
    if (MockDatabase.currentUser != null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primarySky.withOpacity(0.12),
                  ),
                  child: const Icon(Icons.contacts,
                      size: 56, color: AppColors.primarySky),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Enable Contacts Access',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'USafe uses your phonebook to add trusted contacts for SOS alerts. We only store the contacts you choose.',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => _handleContinue(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primarySky,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- 4. LOGIN SCREEN ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    // Validate credentials against the local mock store.
    bool success = await MockDatabase.validateLogin(_emailController.text.trim(), _passwordController.text.trim());
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      final bool authorized = prefs.getBool('authorization_seen') ?? false;
      if (!mounted) return;
      if (!authorized) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthorizationScreen()),
        );
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid email or password."), backgroundColor: AppColors.alertRed, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Center(child: Image.asset('assets/usafe_logo.png', height: 90, errorBuilder: (c, e, s) => const Icon(Icons.shield, size: 80, color: AppColors.primarySky))),
                  const SizedBox(height: 30),
                  const Text("Welcome Back!", textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text("Please sign in to continue", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: AppColors.textGrey)),
                  const SizedBox(height: 50),
                  _buildModernInput(_emailController, "Email", Icons.email_outlined),
                  const SizedBox(height: 20),
                  _buildModernInput(_passwordController, "Password", Icons.lock_outline, isPassword: true),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: const Text("Forgot Password?", style: TextStyle(color: AppColors.primarySky, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF00B4D8), AppColors.primaryNavy], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: AppColors.primarySky.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("LOGIN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Row(children: [Expanded(child: Divider(color: Colors.white12)), Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Or continue with", style: TextStyle(color: AppColors.textGrey))), Expanded(child: Divider(color: Colors.white12))]),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 55,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withOpacity(0.1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), backgroundColor: AppColors.surfaceCard.withOpacity(0.5)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/google.jpg', height: 24, errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 28)),
                          const SizedBox(width: 12),
                          const Text("Google", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text("Don't have an account? ", style: TextStyle(color: AppColors.textGrey)),
                    GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())), child: const Text("Sign Up", style: TextStyle(color: AppColors.primarySky, fontWeight: FontWeight.bold))),
                  ]),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernInput(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: AppColors.textGrey), prefixIcon: Icon(icon, color: AppColors.primarySky), border: InputBorder.none, focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primarySky)), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
      ),
    );
  }
}

// --- 4. SIGNUP SCREEN ---
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController(); 
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        height: double.infinity, 
        width: double.infinity,
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(children: [IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)), const Text("Create Account", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 40),
                  const Text("Join USafe today", style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
                  const SizedBox(height: 40),
                  _buildModernInput(_nameCtrl, "Full Name", Icons.person_outline),
                  const SizedBox(height: 20),
                  _buildModernInput(_emailCtrl, "Email", Icons.email_outlined),
                  const SizedBox(height: 20),
                  _buildModernInput(
                    _phoneCtrl,
                    "Phone Number",
                    Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  ),
                  const SizedBox(height: 20),
                  _buildModernInput(_passCtrl, "Password", Icons.lock_outline, isPassword: true),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00B4D8), AppColors.primaryNavy], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.primarySky.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      
                      onPressed: _isLoading ? null : () async {
                        final phone = _phoneCtrl.text.trim();
                        final isPhoneValid = RegExp(r'^\d{10}$').hasMatch(phone);
                        if (_nameCtrl.text.isNotEmpty && _emailCtrl.text.isNotEmpty && _passCtrl.text.isNotEmpty && isPhoneValid) {
                          setState(() => _isLoading = true);
                          await MockDatabase.registerUser(_nameCtrl.text, _emailCtrl.text, phone, _passCtrl.text);
                          if (!mounted) return;
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account Created! You can Login now."), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.safetyTeal));
                          Navigator.pop(context);
                        } else {
                           final message = !isPhoneValid
                               ? "Phone number must be 10 digits."
                               : "Please fill in all fields.";
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.alertRed));
                        }
                      },
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("CREATE ACCOUNT", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildModernInput(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: AppColors.textGrey), prefixIcon: Icon(icon, color: AppColors.primarySky), border: InputBorder.none, focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primarySky)), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
      ),
    );
  }
}

// --- 5. FORGOT PASSWORD SCREEN ---
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: _buildBackgroundGradient(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Row(children: [IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)), const Text("Reset Password", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 60),
                Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primarySky.withOpacity(0.1)), child: const Icon(Icons.lock_reset, size: 60, color: AppColors.primarySky)),
                const SizedBox(height: 20),
                const Text("Enter your email and we'll send you a link to get back into your account.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey, fontSize: 16, height: 1.5)),
                const SizedBox(height: 40),
                Container(decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))), child: TextFormField(style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Email", labelStyle: TextStyle(color: AppColors.textGrey), prefixIcon: Icon(Icons.email_outlined, color: AppColors.primarySky), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16)))),
                const SizedBox(height: 30),
                Container(width: double.infinity, height: 55, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00B4D8), AppColors.primaryNavy], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.primarySky.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () {ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reset Link Sent!"), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.safetyTeal)); Navigator.pop(context);}, child: const Text("SEND RESET LINK", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}