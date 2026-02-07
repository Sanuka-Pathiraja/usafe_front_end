import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  // Initialize GoogleSignIn
  static final GoogleSignIn googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? "1089719886153-2rrhjocigvsep8p62qrks9fger3e37ee.apps.googleusercontent.com" // only if you use web
        : null,
    scopes: ['email', 'profile'],
  );

  // Method to sign in
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await googleSignIn.signIn();
      return account;
    } catch (e) {
      print("Google Sign-In error: $e");
      return null;
    }
  }

  // Method to sign out (optional)
  static Future<void> signOut() async {
    await googleSignIn.signOut();
  }
}
