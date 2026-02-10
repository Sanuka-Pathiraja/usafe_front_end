import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CheckoutWebView extends StatefulWidget {
  final int amount;
  const CheckoutWebView({super.key, required this.amount});

  @override
  State<CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<CheckoutWebView> {
  WebViewController? controller;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    startCheckout();
  }

  Future<void> startCheckout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      final res = await http.post(
        Uri.parse("http://10.0.2.2:5000/payment/checkout"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"amount": widget.amount}),
      );

      if (res.statusCode == 200) {
        final url = jsonDecode(res.body)["checkoutUrl"];
        setState(() {
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
        });
      } else {
        setState(() => error = "Server error: ${res.statusCode}");
      }
    } catch (e) {
      setState(() => error = "Network failed. Check your connection.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Secure Payment")),
      body: error != null
          ? Center(
              child: Text(error!, style: const TextStyle(color: Colors.red)))
          : controller == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    WebViewWidget(controller: controller!),
                    if (loading)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
    );
  }
}
