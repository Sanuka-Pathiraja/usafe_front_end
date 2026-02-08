import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'app.dart';
import 'features/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣ Set your Stripe publishable key
  Stripe.publishableKey =
      "pk_test_51SwImuLlNAbSbRDVNJv7X5BWmdg3rwURMEfWor7BeXIjSgWx7aKcFBAn1sch1FfH9zWOGTixOvzTFYwYLXjE5sZS00EIhyYGZS";

  // 2️⃣ Optional: set any Stripe settings
  Stripe.merchantIdentifier =
      "merchant.com.example.usafe"; // for Apple Pay if needed
  await Stripe.instance.applySettings();

  // 3️⃣ Optional: Preload token
  final token = await AuthService.getToken();

  runApp(const USafeApp());
}
