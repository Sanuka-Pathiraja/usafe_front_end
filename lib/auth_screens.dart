import 'package:flutter/material.dart';
import 'dart:async';
import 'config.dart';
import 'dashboard.dart';

// --- SPLASH ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(
        const Duration(seconds: 3),
        () => Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                BoxShadow(
                    color: AppColors.primarySky.withOpacity(0.4),
                    blurRadius: 40)
              ]),
              child: Image.asset('assets/usafe_logo.png',
                  errorBuilder: (c, e, s) => const Icon(Icons.shield,
                      size: 80, color: AppColors.primarySky)),
            ),
            const SizedBox(height: 20),
            const Text("USafe",
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// --- LOGIN ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Welcome Back",
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 40),
            TextFormField(
                decoration: const InputDecoration(
                    labelText: "Email", prefixIcon: Icon(Icons.email))),
            const SizedBox(height: 20),
            TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: "Password", prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarySky),
                onPressed: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const DashboardScreen())),
                child: const Text("LOG IN",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
