import 'package:flutter/material.dart';
import 'checkout_webview.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  Future<void> _startPayment(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CheckoutWebView(),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Payment successful")),
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
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Choose the protection you need. Pay only for what matters.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 30),

                // SAFE PATH FEATURE
                _premiumFeatureCard(
                  context,
                  icon: Icons.route,
                  title: "Safe Path Navigation",
                  description:
                      "Automatically reroutes you through the safest areas when danger is detected.",
                  price: "LKR 150",
                  duration: "Monthly",
                  accentColor: Colors.amber,
                  onSubscribe: () => _startPayment(context),
                ),

                const SizedBox(height: 20),

                // OFFLINE FEATURE
                _premiumFeatureCard(
                  context,
                  icon: Icons.cloud_off,
                  title: "Offline Protection Mode",
                  description:
                      "Emergency features continue to work even without internet access.",
                  price: "LKR 200",
                  duration: "Monthly",
                  accentColor: Colors.cyanAccent,
                  onSubscribe: () => _startPayment(context),
                ),

                const Spacer(),
                const Text(
                  "🔒 Secure payments • Cancel anytime",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= Premium Feature Card =================

  Widget _premiumFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String price,
    required String duration,
    required Color accentColor,
    required VoidCallback onSubscribe,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(0.15),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  duration,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton(
                onPressed: onSubscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                ),
                child: const Text(
                  "Subscribe",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
