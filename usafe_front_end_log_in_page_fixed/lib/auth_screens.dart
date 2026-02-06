import 'package:flutter/material.dart';
import 'config.dart';
import 'home_screen.dart';

// ---------------------------------------------------------------------------
// 1. SPLASH SCREEN (Animated Entry)
// ---------------------------------------------------------------------------
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
    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceCard,
                  boxShadow: [BoxShadow(color: AppColors.primarySky.withOpacity(0.2), blurRadius: 40, spreadRadius: 5)],
                ),
                child: Image.asset(
                  'assets/usafe_logo.png', // USafe Logo Asset
                  height: 100,
                  width: 100,
                  errorBuilder: (c, e, s) => const Icon(Icons.shield, size: 100, color: AppColors.primarySky),
                ),
              ),
              const SizedBox(height: 20),
              const Text("USafe", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. AUTH MANAGER (Toggles between Login and Signup)
// ---------------------------------------------------------------------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;

  void _toggleAuth() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLogin) {
      return LoginScreen(onToggle: _toggleAuth);
    } else {
      return SignupScreen(onToggle: _toggleAuth);
    }
  }
}

// ---------------------------------------------------------------------------
// 3. LOGIN SCREEN (The UI from your screenshot)
// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  final VoidCallback? onToggle;
  const LoginScreen({super.key, this.onToggle});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // Simulate loading
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Asset
                Image.asset('assets/usafe_logo.png', height: 80, errorBuilder: (c, e, s) => const Icon(Icons.shield, size: 80, color: AppColors.primarySky)),
                const SizedBox(height: 30),
                const Text("Welcome Back!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                const Text("Sign in to keep your circle safe", style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
                const SizedBox(height: 40),

                _AuthField(controller: _emailController, hint: "Email", icon: Icons.email_outlined),
                const SizedBox(height: 20),
                _AuthField(controller: _passwordController, hint: "Password", icon: Icons.lock_outline, isPassword: true),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () {}, child: const Text("Forgot Password?", style: TextStyle(color: AppColors.primarySky))),
                ),
                const SizedBox(height: 20),

                _PrimaryButton(text: "LOGIN", isLoading: _isLoading, onPressed: _handleLogin),

                if (widget.onToggle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextButton(
                      onPressed: widget.onToggle,
                      child: const Text(
                        "Create New Account",
                        style: TextStyle(
                          color: AppColors.primarySky,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 30),
                _SocialDivider(),
                const SizedBox(height: 30),

                _GoogleButton(onPressed: _handleLogin),

                const SizedBox(height: 40),
                
                if (widget.onToggle != null)
                  _AuthToggle(
                    text: "Don't have an account? ",
                    action: "Sign Up",
                    onTap: widget.onToggle!,
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
// 4. SIGNUP SCREEN (Includes Create Password)
// ---------------------------------------------------------------------------
class SignupScreen extends StatefulWidget {
  final VoidCallback? onToggle;
  const SignupScreen({super.key, this.onToggle});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _handleSignup() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/usafe_logo.png', height: 80, errorBuilder: (c, e, s) => const Icon(Icons.shield_moon, size: 80, color: AppColors.primarySky)),
                const SizedBox(height: 30),
                const Text("Create Account", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                const Text("Join the safety network", style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
                const SizedBox(height: 40),

                _AuthField(controller: _nameController, hint: "Full Name", icon: Icons.person_outline),
                const SizedBox(height: 20),
                _AuthField(controller: _emailController, hint: "Email Address", icon: Icons.email_outlined),
                const SizedBox(height: 20),
                _AuthField(controller: _passwordController, hint: "Create Password", icon: Icons.lock_outline, isPassword: true),

                const SizedBox(height: 30),

                _PrimaryButton(text: "SIGN UP", isLoading: _isLoading, onPressed: _handleSignup),

                const SizedBox(height: 30),
                _SocialDivider(),
                const SizedBox(height: 30),

                _GoogleButton(onPressed: _handleSignup),

                const SizedBox(height: 40),

                if (widget.onToggle != null)
                  _AuthToggle(
                    text: "Already have an account? ",
                    action: "Log In",
                    onTap: widget.onToggle!,
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
// SHARED WIDGETS
// ---------------------------------------------------------------------------

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPassword;

  const _AuthField({required this.controller, required this.hint, required this.icon, this.isPassword = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: AppColors.primarySky),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.text, required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primarySky,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 5,
          shadowColor: AppColors.primarySky.withOpacity(0.4),
        ),
        child: isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _GoogleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Image.asset(
          'assets/google.jpg', // Google Asset
          height: 24, 
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.public, color: Colors.white)
        ),
        label: const Text("Continue with Google"),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _SocialDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.white24)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text("OR", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        ),
        const Expanded(child: Divider(color: Colors.white24)),
      ],
    );
  }
}

class _AuthToggle extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onTap;

  const _AuthToggle({required this.text, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text, style: const TextStyle(color: AppColors.textGrey)),
        GestureDetector(
          onTap: onTap,
          child: Text(action, style: const TextStyle(color: AppColors.primarySky, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}