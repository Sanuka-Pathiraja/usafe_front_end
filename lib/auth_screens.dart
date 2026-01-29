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
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

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
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 140,
                width: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primarySky.withOpacity(0.3),
                        blurRadius: 50,
                        spreadRadius: 5)
                  ],
                ),
                child: Image.asset('assets/usafe_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const Icon(Icons.shield,
                        size: 80, color: AppColors.primarySky)),
              ),
              const SizedBox(height: 20),
              const Text("USafe",
                  style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textWhite,
                      letterSpacing: 2)),
              const SizedBox(height: 10),
              const Text("Intelligent Personal Safety",
                  style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primarySky.withOpacity(0.2),
                        blurRadius: 30)
                  ],
                ),
                child: Image.asset('assets/usafe_logo.png',
                    errorBuilder: (c, e, s) => const Icon(Icons.shield,
                        size: 60, color: AppColors.primarySky)),
              ),
              const SizedBox(height: 30),
              const Text("Welcome Back",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite)),
              const Text("Secure. Protected. Connected.",
                  style: TextStyle(color: AppColors.textGrey)),
              const SizedBox(height: 40),
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email_outlined)),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: "Password",
                        prefixIcon: Icon(Icons.lock_outline)),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () {},
                        child: const Text("Forgot Password?",
                            style: TextStyle(color: AppColors.primarySky))),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primarySky,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 5,
                          shadowColor: AppColors.primarySky.withOpacity(0.4)),
                      child: const Text("LOG IN",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[800]!),
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
                              color: Colors.white)),
                      const SizedBox(width: 12),
                      const Text("Continue with Google",
                          style: TextStyle(color: AppColors.textWhite)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SignupScreen())),
                child: const Text("Create Account",
                    style: TextStyle(
                        color: AppColors.primarySky,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final name = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();

    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context))),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Create Account",
                style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 32,
                    fontWeight: FontWeight.bold)),
            const Text("Join the USafe network.",
                style: TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 40),
            TextFormField(
                controller: name,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Full Name", prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 20),
            TextFormField(
                controller: email,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Email", prefixIcon: Icon(Icons.email))),
            const SizedBox(height: 20),
            TextFormField(
                controller: pass,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Password", prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarySky,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  MockDatabase.registerUser(name.text, email.text, pass.text);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DashboardScreen()));
                },
                child: const Text("REGISTER",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
