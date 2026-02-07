import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'app.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final stripeKey = const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
  if (stripeKey.isNotEmpty) {
    Stripe.publishableKey = stripeKey;
  }
  await MockDatabase.loadUserSession();
  runApp(const USafeApp());
}
