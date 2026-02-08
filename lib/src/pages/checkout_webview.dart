import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CheckoutWebView extends StatefulWidget {
  const CheckoutWebView({super.key});

  @override
  State<CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<CheckoutWebView> {
  late final WebViewController controller;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    startCheckout();
  }

  Future<void> startCheckout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    final res = await http.post(
      Uri.parse("http://10.0.2.2:5000/payment/checkout"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"amount": 10}),
    );

    final url = jsonDecode(res.body)["checkoutUrl"];

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => loading = false),
          onNavigationRequest: (request) {
            if (request.url.contains("/payment/success")) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }
            if (request.url.contains("/payment/cancel")) {
              Navigator.pop(context, false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payments", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
