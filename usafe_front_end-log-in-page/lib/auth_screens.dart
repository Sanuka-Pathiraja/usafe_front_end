import 'package:flutter/material.dart';
import 'config.dart';
import 'home_screen.dart';
<<<<<<< HEAD

// --- THEME HELPER ---
BoxDecoration _buildBackgroundGradient() {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.background, AppColors.backgroundBlack],
    ),
  );
}

// --- 1. SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
=======

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

>>>>>>> 25864e455d2821af66d1bef5c853f0886afc4387
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

<<<<<<< HEAD
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
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
=======
class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
>>>>>>> 25864e455d2821af66d1bef5c853f0886afc4387

  @override
  Widget build(BuildContext context) {
    return Scaffold(
<<<<<<< HEAD
      backgroundColor: AppColors.background,
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
                  // FIX: Use Icon instead of Image to prevent crash
                  child: const Icon(Icons.shield, size: 100, color: AppColors.primarySky),
                ),
                const SizedBox(height: 30),
                const Text("USafe", style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: Colors.white)),
              ],
            ),
=======
      // 1. SINGLE COLOR BACKGROUND
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 2. USAFE LOGO (Top)
              Image.asset(
                'assets/usafe_logo.png',
                height: 120, // Adjust size as needed
                errorBuilder: (context, error, stackTrace) {
                  // Fallback icon if image is missing/fails to load
                  return const Icon(Icons.shield_moon, size: 80, color: AppColors.primary);
                },
              ),
              const SizedBox(height: 30),

              Text(
                _isLogin ? "Welcome Back" : "Create Account",
                style: const TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isLogin ? "Sign in to continue" : "Join the safety network",
                style: const TextStyle(color: AppColors.textSub, fontSize: 16),
              ),
              const SizedBox(height: 40),

              // Fields
              if (!_isLogin) ...[
                _buildGlassField(Icons.person_outline, "Full Name"),
                const SizedBox(height: 16),
              ],
              _buildGlassField(Icons.email_outlined, "Email Address"),
              const SizedBox(height: 16),
              _buildGlassField(Icons.lock_outline, "Password", isPassword: true),

              // 3. FORGOT PASSWORD (Only in Login mode)
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Add Forgot Password logic here
                    },
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),

              // Main Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _isLogin ? "SIGN IN" : "SIGN UP",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white24)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text("OR", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                  ),
                  const Expanded(child: Divider(color: Colors.white24)),
                ],
              ),

              const SizedBox(height: 24),

              // 4. GOOGLE SIGN IN BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    // Add Google Sign-In Logic Here
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/google.jpg',
                        height: 24,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.public, color: Colors.black),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Sign in with Google",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Toggle Login/Signup
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: AppColors.textSub),
                    children: [
                      TextSpan(text: _isLogin ? "New to USafe? " : "Already have an account? "),
                      TextSpan(
                        text: _isLogin ? "Sign Up" : "Log In",
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
>>>>>>> 25864e455d2821af66d1bef5c853f0886afc4387
          ),
        ),
      ),
    );
  }

<<<<<<< HEAD
// --- 2. LOGIN SCREEN ---
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
    await Future.delayed(const Duration(seconds: 1)); // Simulating login
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
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
                  // FIX: Use Icon instead of Image
                  const Icon(Icons.shield, size: 80, color: AppColors.primarySky),
                  const SizedBox(height: 30),
                  const Text("Welcome Back!", textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 50),
                  
                  _buildModernInput(_emailController, "Email", Icons.email_outlined),
                  const SizedBox(height: 20),
                  _buildModernInput(_passwordController, "Password", Icons.lock_outline, isPassword: true),
                  
                  const SizedBox(height: 30),
                  
                  // Login Button
                  Container(
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF00B4D8), AppColors.primaryNavy], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("LOGIN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  const Text("Or continue with Google", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernInput(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: TextFormField(
        controller: controller, 
        obscureText: isPassword, 
        style: const TextStyle(color: Colors.white), 
        decoration: InputDecoration(
          labelText: label, 
          labelStyle: const TextStyle(color: AppColors.textGrey), 
          prefixIcon: Icon(icon, color: AppColors.primarySky), 
          border: InputBorder.none, 
        )
      ),
    );
  }
}

// --- 3. SIGNUP SCREEN (Placeholder) ---
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("Signup")));
  }
}

// --- 4. FORGOT PASSWORD (Placeholder) ---
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("Forgot Password")));
  }
=======
  Widget _buildGlassField(IconData icon, String hint, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.textSub),
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textSub.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
>>>>>>> 25864e455d2821af66d1bef5c853f0886afc4387
}