import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/features/auth/google_auth_service.dart';
import 'package:usafe_front_end/features/onboarding/onboarding_controller.dart';
import 'package:usafe_front_end/features/onboarding/screens/emergency_contacts_setup_screen.dart';
import 'package:usafe_front_end/src/pages/home_screen.dart';

// --- 1. THEME BACKGROUND ---
BoxDecoration _buildBackgroundGradient() {
  return const BoxDecoration(color: AppColors.background);
}

// --- 2. SPLASH SCREEN ---
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
                      color: AppColors.primarySky.withValues(alpha: 0.1),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primarySky.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 5)
                      ]),
                  child: Image.asset('assets/usafe_logo.png',
                      height: 120,
                      errorBuilder: (c, e, s) => const Icon(Icons.shield,
                          size: 100, color: AppColors.primarySky)),
                ),
                const SizedBox(height: 30),
                const Text("USafe",
                    style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Colors.white)),
                const SizedBox(height: 10),
                const Text("Intelligent Personal Safety",
                    style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 14,
                        letterSpacing: 1.0)),
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
  final bool startContactsTour;

  const AuthorizationScreen({super.key, this.startContactsTour = false});

  Future<Widget> _buildNextScreen() async {
    if (!startContactsTour) {
      return const HomeScreen();
    }
    try {
      final contacts = await AuthService.fetchContacts();
      if (contacts.length >= 3) {
        return const HomeScreen();
      }
    } catch (_) {
      try {
        final cached = await AuthService.loadTrustedContacts();
        if (cached.length >= 3) {
          return const HomeScreen();
        }
      } catch (_) {}
    }
    return const HomeScreen(
      initialTabIndex: 2,
      startContactsTour: true,
    );
  }

  Future<void> _handleContinue(BuildContext context) async {
    // Request contacts permission and mark the step as completed.
    await FlutterContacts.requestPermission(readonly: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('authorization_seen', true);

    if (!context.mounted) return;
    if (MockDatabase.currentUser != null) {
      final nextScreen = await _buildNextScreen();
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextScreen),
      );
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
                    color: AppColors.primarySky.withValues(alpha: 0.12),
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
  bool _showOnboarding = false;

  final _emailKey = GlobalKey();
  final _passwordKey = GlobalKey();
  final _loginButtonKey = GlobalKey();
  final _googleButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final should = await OnboardingController.shouldShowLoginTour();
    if (!should || !mounted) return;
    setState(() => _showOnboarding = true);
  }

  void _dismissOnboarding() {
    OnboardingController.markLoginTourSeen();
    setState(() => _showOnboarding = false);
  }

  Future<Widget> _resolvePostLoginHome() async {
    try {
      final contacts = await AuthService.fetchContacts();
      if (contacts.length >= 3) {
        return const HomeScreen();
      }
    } catch (_) {
      try {
        final cached = await AuthService.loadTrustedContacts();
        if (cached.length >= 3) {
          return const HomeScreen();
        }
      } catch (_) {}
    }
    return const EmergencyContactsSetupScreen();
  }

  Future<void> _goToPostLoginHome() async {
    final nextScreen = await _resolvePostLoginHome();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  void _handleLogin() async {
    setState(() => _isLoading = true);
    final success = await AuthService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      await _goToPostLoginHome();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Invalid email or password."),
            backgroundColor: AppColors.alertRed,
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
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
                      Center(
                          child: Image.asset('assets/usafe_logo.png',
                              height: 130,
                              errorBuilder: (c, e, s) => const Icon(Icons.shield,
                                  size: 120, color: AppColors.primarySky))),
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
                          style: TextStyle(
                              fontSize: 16, color: AppColors.textGrey)),
                      const SizedBox(height: 50),
                      SizedBox(
                        key: _emailKey,
                        child: _buildModernInput(
                            _emailController, "Email", Icons.email_outlined),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        key: _passwordKey,
                        child: _buildModernInput(
                            _passwordController, "Password", Icons.lock_outline,
                            isPassword: true),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ForgotPasswordScreen())),
                          child: const Text("Forgot Password?",
                              style: TextStyle(
                                  color: AppColors.primarySky,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        key: _loginButtonKey,
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text("LOGIN",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2)),
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Row(children: [
                        Expanded(child: Divider(color: Colors.white12)),
                        Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text("Or continue with",
                                style: TextStyle(color: AppColors.textGrey))),
                        Expanded(child: Divider(color: Colors.white12))
                      ]),
                      const SizedBox(height: 30),
                      SizedBox(
                        key: _googleButtonKey,
                        height: 55,
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                setState(() => _isLoading = true);
                                final googleResult =
                                    await GoogleAuthService
                                        .signInForBackend();
                                if (!googleResult.success ||
                                    (googleResult.idToken ?? '').isEmpty) {
                                  if (!mounted) return;
                                  setState(() => _isLoading = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        googleResult.message ??
                                            'Google sign-in failed.',
                                      ),
                                      backgroundColor: AppColors.alertRed,
                                    ),
                                  );
                                  return;
                                }

                                final result =
                                    await AuthService.googleLoginDetailed(
                                  googleResult.idToken!,
                                  accessToken: googleResult.accessToken,
                                );
                                final success = result['success'] == true;
                                if (!mounted) return;
                                setState(() => _isLoading = false);
                                if (success) {
                                  await _goToPostLoginHome();
                                } else {
                                  final message = (result['message'] ??
                                      'Google login failed.')
                                      .toString();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(message),
                                      backgroundColor: AppColors.alertRed,
                                    ),
                                  );
                                }
                              },
                          style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              backgroundColor:
                                  AppColors.surfaceCard.withValues(alpha: 0.5)),
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
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
                                    fontWeight: FontWeight.bold))),
                      ]),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_showOnboarding)
          _AuthOnboardingOverlay(
            steps: _kLoginSteps,
            stepKeys: [_emailKey, _passwordKey, _loginButtonKey, _googleButtonKey],
            onDone: _dismissOnboarding,
          ),
      ],
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
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}

// --- 5. SIGNUP SCREEN ---
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
  bool _showOnboarding = false;

  final _nameKey = GlobalKey();
  final _phoneKey = GlobalKey();
  final _emailKey = GlobalKey();
  final _passwordKey = GlobalKey();
  final _createKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final should = await OnboardingController.shouldShowSignupTour();
    if (!should || !mounted) return;
    setState(() => _showOnboarding = true);
  }

  void _dismissOnboarding() {
    OnboardingController.markSignupTourSeen();
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
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
                      Row(children: [
                        IconButton(
                            icon: const Icon(Icons.arrow_back_ios,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context)),
                        const Text("Create Account",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold))
                      ]),
                      const SizedBox(height: 40),
                      const Text("Join USafe today",
                          style:
                              TextStyle(color: AppColors.textGrey, fontSize: 16)),
                      const SizedBox(height: 40),
                      SizedBox(
                        key: _nameKey,
                        child: _buildModernInput(
                            _nameCtrl, "Full Name", Icons.person_outline),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        key: _phoneKey,
                        child: _buildModernInput(
                          _phoneCtrl,
                          "Phone Number",
                          Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10)
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        key: _emailKey,
                        child: _buildModernInput(
                            _emailCtrl, "Email", Icons.email_outlined),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        key: _passwordKey,
                        child: _buildModernInput(
                            _passCtrl, "Password", Icons.lock_outline,
                            isPassword: true),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        key: _createKey,
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF00B4D8), AppColors.primaryNavy],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.primarySky.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6))
                            ]),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16))),
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  final nav = Navigator.of(context);
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final phone = _phoneCtrl.text.trim();
                                  final isPhoneValid =
                                      RegExp(r'^\d{10}$').hasMatch(phone);
                                  if (_nameCtrl.text.isNotEmpty &&
                                      _emailCtrl.text.isNotEmpty &&
                                      _passCtrl.text.isNotEmpty &&
                                      isPhoneValid) {
                                    setState(() => _isLoading = true);
                                    final parts = _nameCtrl.text
                                        .trim()
                                        .split(RegExp(r'\s+'));
                                    final firstName = parts.isNotEmpty
                                        ? parts.first
                                        : _nameCtrl.text;
                                    final lastName = parts.length > 1
                                        ? parts.sublist(1).join(' ')
                                        : '-';
                                    final success = await AuthService.signup(
                                      firstName: firstName,
                                      lastName: lastName,
                                      age: 18,
                                      phone: phone,
                                      email: _emailCtrl.text.trim(),
                                      password: _passCtrl.text,
                                    );
                                    if (!mounted) return;
                                    setState(() => _isLoading = false);
                                    if (success) {
                                      nav.pushAndRemoveUntil(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const EmergencyContactsSetupScreen()),
                                        (_) => false,
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text("Signup failed."),
                                          backgroundColor: AppColors.alertRed,
                                        ),
                                      );
                                    }
                                  } else {
                                    final message = !isPhoneValid
                                        ? "Phone number must be 10 digits."
                                        : "Please fill in all fields.";
                                    messenger.showSnackBar(
                                        SnackBar(
                                            content: Text(message),
                                            backgroundColor: AppColors.alertRed));
                                  }
                                },
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("CREATE ACCOUNT",
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
          ),
        ),
        if (_showOnboarding)
          _AuthOnboardingOverlay(
            steps: _kSignupSteps,
            stepKeys: [_nameKey, _phoneKey, _emailKey, _passwordKey, _createKey],
            onDone: _dismissOnboarding,
          ),
      ],
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
      decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: AppColors.textGrey),
            prefixIcon: Icon(icon, color: AppColors.primarySky),
            border: InputBorder.none,
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primarySky)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
      ),
    );
  }
}

// --- 6. FORGOT PASSWORD SCREEN ---
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
                Row(children: [
                  IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context)),
                  const Text("Reset Password",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold))
                ]),
                const SizedBox(height: 60),
                Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primarySky.withValues(alpha: 0.1)),
                    child: const Icon(Icons.lock_reset,
                        size: 60, color: AppColors.primarySky)),
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
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.05))),
                    child: TextFormField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            labelText: "Email",
                            labelStyle: TextStyle(color: AppColors.textGrey),
                            prefixIcon: Icon(Icons.email_outlined,
                                color: AppColors.primarySky),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16)))),
                const SizedBox(height: 30),
                Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF00B4D8), AppColors.primaryNavy],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primarySky.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6))
                        ]),
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16))),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Reset Link Sent!"),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.safetyTeal));
                          Navigator.pop(context);
                        },
                        child: const Text("SEND RESET LINK",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step data ─────────────────────────────────────────────────────────────────

class _AuthStep {
  final IconData icon;
  final Color color;
  final String label;
  final String title;
  final String body;
  const _AuthStep({
    required this.icon,
    required this.color,
    required this.label,
    required this.title,
    required this.body,
  });
}

const _kLoginSteps = [
  _AuthStep(
    icon: Icons.email_outlined,
    color: Color(0xFF3B82F6),
    label: 'Your email',
    title: 'Sign in with your email',
    body:
        'Enter the email address you used when creating your USafe account.',
  ),
  _AuthStep(
    icon: Icons.lock_outline,
    color: Color(0xFF8B5CF6),
    label: 'Your password',
    title: 'Enter your password',
    body:
        'Your password is encrypted and kept secure. Use "Forgot Password?" below if you need to reset it.',
  ),
  _AuthStep(
    icon: Icons.login_rounded,
    color: Color(0xFF10B981),
    label: 'Log in',
    title: 'Tap to sign in',
    body:
        'Hit Login to access your USafe account and stay protected wherever you go.',
  ),
  _AuthStep(
    icon: Icons.g_mobiledata,
    color: Color(0xFFEF4444),
    label: 'Google sign-in',
    title: 'Or sign in with Google',
    body:
        'Skip the password — sign in instantly with your Google account. Fast, safe, and secure.',
  ),
];

const _kSignupSteps = [
  _AuthStep(
    icon: Icons.person_outline,
    color: Color(0xFF3B82F6),
    label: 'Your name',
    title: 'Enter your full name',
    body:
        'Use your real name so your trusted contacts can identify you quickly in an emergency.',
  ),
  _AuthStep(
    icon: Icons.phone_outlined,
    color: Color(0xFF10B981),
    label: 'Phone number',
    title: 'Your 10-digit number',
    body:
        'Enter a valid mobile number (e.g. 0771234567). This is linked to your SOS alerts.',
  ),
  _AuthStep(
    icon: Icons.email_outlined,
    color: Color(0xFF8B5CF6),
    label: 'Your email',
    title: 'Enter your email address',
    body:
        'Use an email you check regularly — important alerts and account info will be sent here.',
  ),
  _AuthStep(
    icon: Icons.lock_outline,
    color: Color(0xFFF59E0B),
    label: 'Secure password',
    title: 'Create a strong password',
    body:
        'Use a mix of letters, numbers, and symbols. A strong password keeps your account safe.',
  ),
  _AuthStep(
    icon: Icons.person_add_rounded,
    color: Color(0xFF06B6D4),
    label: 'Create account',
    title: 'Ready to join USafe?',
    body:
        "Tap Create Account to get started. You'll be guided to set up your emergency contacts next.",
  ),
];

// ── Spotlight painter ─────────────────────────────────────────────────────────

class _AuthSpotlightPainter extends CustomPainter {
  final Rect? highlight;
  final Color glowColor;
  final double glowT;

  const _AuthSpotlightPainter({
    required this.highlight,
    required this.glowColor,
    required this.glowT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Rect.fromLTWH(0, 0, size.width, size.height);

    if (highlight == null) {
      canvas.drawRect(
          screen, Paint()..color = Colors.black.withValues(alpha: 0.88));
      return;
    }

    const radius = Radius.circular(22);
    final inflated = highlight!.inflate(10);
    final rrect = RRect.fromRectAndRadius(inflated, radius);

    // 1 ── Dark overlay with the highlight punched out
    final overlay = Path()..addRect(screen);
    final hole = Path()..addRRect(rrect);
    final cutout = Path.combine(PathOperation.difference, overlay, hole);
    canvas.drawPath(
        cutout, Paint()..color = Colors.black.withValues(alpha: 0.86));

    // 2 ── Subtle colour wash inside the highlight
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = glowColor.withValues(alpha: 0.06 + 0.04 * glowT)
        ..style = PaintingStyle.fill,
    );

    // 3 ── Outer diffused glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(inflated.inflate(6), radius),
      Paint()
        ..color = glowColor.withValues(alpha: 0.18 * glowT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // 4 ── Medium glow ring
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = glowColor.withValues(alpha: 0.45 * glowT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // 5 ── Crisp inner border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = glowColor.withValues(alpha: 0.65 + 0.35 * glowT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_AuthSpotlightPainter old) =>
      old.highlight != highlight ||
      old.glowColor != glowColor ||
      old.glowT != glowT;
}

// ── Auth Onboarding Overlay ───────────────────────────────────────────────────

class _AuthOnboardingOverlay extends StatefulWidget {
  final VoidCallback onDone;
  final List<GlobalKey> stepKeys;
  final List<_AuthStep> steps;

  const _AuthOnboardingOverlay({
    required this.onDone,
    required this.stepKeys,
    required this.steps,
  });

  @override
  State<_AuthOnboardingOverlay> createState() => _AuthOnboardingOverlayState();
}

class _AuthOnboardingOverlayState extends State<_AuthOnboardingOverlay>
    with TickerProviderStateMixin {
  int _step = 0;
  Rect? _highlightRect;

  late final AnimationController _glowCtrl;
  late final AnimationController _slideCtrl;
  late final AnimationController _rippleCtrl;

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450))
      ..forward();

    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollAndMeasure());
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _slideCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  Future<void> _scrollAndMeasure() async {
    final key = widget.stepKeys[_step];
    if (key.currentContext == null) return;

    await Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.3,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOut,
    );

    await Future.delayed(const Duration(milliseconds: 40));
    if (!mounted) return;
    _measureRect();
  }

  void _measureRect() {
    final key = widget.stepKeys[_step];
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final pos = box.localToGlobal(Offset.zero);
    if (mounted) setState(() => _highlightRect = pos & box.size);
  }

  Future<void> _advance() async {
    if (_step < widget.steps.length - 1) {
      setState(() {
        _step++;
        _highlightRect = null;
      });
      _slideCtrl
        ..reset()
        ..forward();
      _rippleCtrl.reset();
      await _scrollAndMeasure();
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_step];
    final color = step.color;
    final isLast = _step == widget.steps.length - 1;
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;
    final bottomPad = mq.padding.bottom;
    final screenH = mq.size.height;

    double? calloutTop;
    double? calloutBottom;
    if (_highlightRect != null) {
      final spaceAbove = _highlightRect!.top - topPad - 80;
      if (spaceAbove >= 40) {
        calloutTop = _highlightRect!.top - 48;
      } else {
        calloutBottom = screenH - _highlightRect!.bottom - 8;
      }
    }

    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: Stack(
        children: [
          // ── Spotlight painter ─────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: AnimatedBuilder(
                animation: _glowCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _AuthSpotlightPainter(
                    highlight: _highlightRect,
                    glowColor: color,
                    glowT: 0.55 + 0.45 * _glowCtrl.value,
                  ),
                ),
              ),
            ),
          ),

          // ── Expanding ripple on the highlighted section ───────────────
          if (_highlightRect != null)
            AnimatedBuilder(
              animation: _rippleCtrl,
              builder: (_, __) {
                final t = _rippleCtrl.value;
                final expand = t * 18.0;
                final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.7;
                final rect = _highlightRect!.inflate(10 + expand);
                return Positioned(
                  left: rect.left,
                  top: rect.top,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: rect.width,
                        height: rect.height,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: color, width: 2),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // ── Callout label near highlight ──────────────────────────────
          if (_highlightRect != null)
            Positioned(
              top: calloutTop,
              bottom: calloutBottom,
              left: _highlightRect!.left,
              right: mq.size.width - _highlightRect!.right,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(step.icon, color: color, size: 13),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          step.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Skip button ───────────────────────────────────────────────
          Positioned(
            top: topPad + 14,
            right: 20,
            child: GestureDetector(
              onTap: widget.onDone,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),

          // ── Step counter ──────────────────────────────────────────────
          Positioned(
            top: topPad + 14,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Container(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${_step + 1} of ${widget.steps.length}',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Slide-up card ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.28),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: _slideCtrl,
                  curve: Curves.easeOutCubic)),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    26, 24, 26, 20 + bottomPad),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32)),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress dots
                    Row(
                      children: List.generate(
                        widget.steps.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _step ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _step
                                ? color
                                : Colors.white
                                    .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Icon + title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: color.withValues(alpha: 0.45)),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Icon(step.icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            child: Text(
                              step.title,
                              key: ValueKey('t$_step'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Body
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: Text(
                        step.body,
                        key: ValueKey('b$_step'),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // CTA button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.42),
                            blurRadius: 22,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _advance,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLast ? "Let's go" : 'Next',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isLast
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
