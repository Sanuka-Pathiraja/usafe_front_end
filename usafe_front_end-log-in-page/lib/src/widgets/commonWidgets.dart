
// lib/src/features/authentication/presentation/login_screen.dart

import 'package:flutter/material.dart';
// import 'widgets/login_form.dart'; // Local import

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome Back')),
      body: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            // child: LoginForm(), // Extracted widget
          ),
        ),
      ),
    );
  }
}