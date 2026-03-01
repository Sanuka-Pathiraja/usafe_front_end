import 'package:flutter/material.dart';
import 'checkout_webview.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  Future<void> _startPayment(BuildContext context, int amount) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutWebView(amount: amount),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("✅ Payment successful"),
            backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Text(
                  "Premium Features",
                  style: TextStyle(
                      color: Colors.amber,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                _premiumFeatureCard(
                  context,
                  icon: Icons.route,
                  title: "Safe Path Navigation",
                  description:
                      "Reroutes you through the safest areas automatically.",
                  price: "LKR 160", // Increased to meet Stripe minimum
                  accentColor: Colors.amber,
                  onSubscribe: () => _startPayment(context, 160),
                ),
                const SizedBox(height: 20),
                _premiumFeatureCard(
                  context,
                  icon: Icons.cloud_off,
                  title: "Offline Protection Mode",
                  description:
                      "Emergency features work without internet access.",
                  price: "LKR 210", // Increased
                  accentColor: Colors.cyanAccent,
                  onSubscribe: () => _startPayment(context, 210),
                ),
                const Spacer(),
                const Text("🔒 Secure payments • Cancel anytime",
                    style: TextStyle(color: Colors.white38)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _premiumFeatureCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String description,
      required String price,
      required Color accentColor,
      required VoidCallback onSubscribe}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 26),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(description, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(price,
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: onSubscribe,
                style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black),
                child: const Text("Subscribe"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
