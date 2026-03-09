import 'dart:convert';
import 'dart:io'; // Crucial for iOS vs Android IP
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
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPayment();
  }

  Future<void> _initPayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      // iOS = localhost, Android = 10.0.2.2
      final String domain = Platform.isAndroid ? "10.0.2.2" : "localhost";
      final url = Uri.parse("http://$domain:5000/payment/checkout");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"amount": widget.amount}),
      );

      if (response.statusCode == 200) {
        final checkoutUrl = jsonDecode(response.body)["checkoutUrl"];

        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (_) => setState(() => _isLoading = false),
              onNavigationRequest: (request) {
                if (request.url.contains("/success")) {
                  Navigator.pop(context, true);
                  return NavigationDecision.prevent;
                }
                if (request.url.contains("/cancel")) {
                  Navigator.pop(context, false);
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(checkoutUrl));

        setState(() => _controller = controller);
      } else {
        setState(() => _errorMessage = "Server Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _errorMessage = "Failed to connect to backend.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Secure Checkout")),
      // SizedBox.expand forces the child to be exactly the size of the screen
      body: SizedBox.expand(
        child: _buildUI(),
      ),
    );
  }

  Widget _buildUI() {
    if (_errorMessage != null) {
      return Center(
          child:
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    }
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
