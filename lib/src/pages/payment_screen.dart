import 'package:flutter/material.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'checkout_webview.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  void _openCheckout(BuildContext context, int amount) async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CheckoutWebView(amount: amount)),
    );

    if (context.mounted && success != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Payment Successful!" : "Payment Cancelled"),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Widget _planCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int price,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primarySky.withOpacity(0.15),
        ),
      ),
      child: Column(
        children: [
          /// ICON + TITLE + PRICE
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primarySky, size: 22),
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
              Text(
                "LKR $price",
                style: const TextStyle(
                  color: AppColors.primarySky,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),

          const SizedBox(height: 10),

          /// SUBTITLE
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textGrey,
            ),
          ),

          const SizedBox(height: 18),

          /// BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openCheckout(context, price),
              icon: const Icon(Icons.lock_open),
              label: const Text("Activate Plan"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.safetyTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Safety Plans"),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            _planCard(
              context,
              icon: Icons.route,
              title: "Safe Path AI",
              subtitle: "Real-time rerouting through safer streets.",
              price: 160,
            ),
            _planCard(
              context,
              icon: Icons.shield_outlined,
              title: "Offline Guard",
              subtitle: "Emergency SOS protection even without internet.",
              price: 210,
            ),
            const SizedBox(height: 20),
            const Text(
              "🔒 Secure & encrypted payment",
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
