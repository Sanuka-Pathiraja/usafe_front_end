import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInAttemptResult {
  final bool success;
  final String? idToken;
  final String? accessToken;
  final String? message;
  final String? debugCode;

  const GoogleSignInAttemptResult({
    required this.success,
    this.idToken,
    this.accessToken,
    this.message,
    this.debugCode,
  });
}

class GoogleAuthService {
  // This must be your Web OAuth Client ID from Google Cloud Console.
  static const String _webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '1089719886153-2rrhjocigvsep8p62qrks9fger3e37ee.apps.googleusercontent.com',
  );

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const [
      'openid',
      'email',
      'profile',
      'https://www.googleapis.com/auth/user.birthday.read',
      'https://www.googleapis.com/auth/user.phonenumbers.read',
    ],
    serverClientId: _webClientId,
    clientId: kIsWeb ? _webClientId : null,
  );

  static const List<String> _peopleScopes = <String>[
    'https://www.googleapis.com/auth/user.birthday.read',
    'https://www.googleapis.com/auth/user.phonenumbers.read',
  ];

  static Future<GoogleSignInAttemptResult> signInForBackend() async {
    try {
      // Ensure fresh token retrieval.
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();
      if (account == null) {
        return const GoogleSignInAttemptResult(
          success: false,
          message: 'Google sign-in cancelled.',
          debugCode: 'cancelled',
        );
      }

      // Ensure sensitive People API scopes are explicitly granted.
      final granted = await _googleSignIn.requestScopes(_peopleScopes);
      if (!granted) {
        return const GoogleSignInAttemptResult(
          success: false,
          message:
              'Birthday/phone permission was not granted in Google consent.',
          debugCode: 'people_scopes_not_granted',
        );
      }

      final auth = await account.authentication;
      final idToken = (auth.idToken ?? '').trim();
      final accessToken = (auth.accessToken ?? '').trim();
      if (idToken.isEmpty) {
        return const GoogleSignInAttemptResult(
          success: false,
          message:
              'Google idToken is empty. Verify Web Client ID and SHA-1 setup.',
          debugCode: 'id_token_empty',
        );
      }

      return GoogleSignInAttemptResult(
        success: true,
        idToken: idToken,
        accessToken: accessToken.isEmpty ? null : accessToken,
      );
    } on PlatformException catch (e) {
      final raw = '${e.code} ${e.message ?? ''}';
      final lower = raw.toLowerCase();

      if (lower.contains('apiexception: 10') ||
          lower.contains('developer_error')) {
        return const GoogleSignInAttemptResult(
          success: false,
          message:
              'Google Sign-In configuration error (ApiException 10). Check package name, SHA-1, and Web Client ID.',
          debugCode: 'api_exception_10',
        );
      }

      return GoogleSignInAttemptResult(
        success: false,
        message: 'Google Sign-In failed: ${e.message ?? e.code}',
        debugCode: e.code,
      );
    } catch (e) {
      return GoogleSignInAttemptResult(
        success: false,
        message: 'Google Sign-In failed: $e',
        debugCode: 'unknown_exception',
      );
    }
  }

  static Future<void> signOut() => _googleSignIn.signOut();
}
