import 'package:flutter_stripe/flutter_stripe.dart';

class StripeConfig {
  static void init() {
    Stripe.publishableKey =
        "pk_test_XXXXXXXXXXXXXXXXXXXX"; // Your Stripe test key
    Stripe.merchantIdentifier = "Test Merchant";
    Stripe.urlScheme = "flutterstripe";
  }
}
