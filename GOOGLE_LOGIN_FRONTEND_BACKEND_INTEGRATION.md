# Google Login Integration Report (Flutter + Backend)

Date: 2026-03-08  
App: `usafe_front_end`  
Backend Endpoint: `POST /user/googleLogin`

## Implemented Frontend Flow

1. User taps Google button.
2. App runs `GoogleAuthService.signInForBackend()`.
3. App requests Google account + `idToken`.
4. App sends `idToken` to backend via `AuthService.googleLoginDetailed(idToken)`.
5. Backend returns SafeZone JWT (`token`) + `user`.
6. App stores JWT/session and routes to:
   - `AuthorizationScreen` if first-time contacts permission not completed.
   - `HomeScreen` otherwise.

## Files Updated

- `lib/features/auth/google_auth_service.dart`
  - New robust sign-in result model: `GoogleSignInAttemptResult`
  - New method: `signInForBackend()`
  - Better error categorization:
    - cancelled
    - id token missing
    - ApiException 10 (Google config mismatch)

- `lib/features/auth/screens/login_screen.dart`
  - Google button now uses `signInForBackend()`
  - Shows exact error text from Google step or backend step
  - Uses same post-login routing logic as email login flow

## Backend Contract Used

`POST /user/googleLogin`

Request:
```json
{
  "idToken": "<google_id_token>"
}
```

Success:
```json
{
  "success": true,
  "message": "Google login successful",
  "token": "<safezone_jwt>",
  "user": { "...": "..." }
}
```

## Required Configuration (Critical)

To avoid `ApiException: 10 (DEVELOPER_ERROR)`, all of these must match:

1. **Android package name** in Google Console OAuth Android client  
   Current app package: `com.example.usafe_fresh`

2. **SHA-1 fingerprint** of debug/release signing key  
   (debug while testing with `flutter run`)

3. **Web OAuth Client ID**  
   Must be passed to Flutter:
   ```bash
   flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=<REAL_WEB_CLIENT_ID>.apps.googleusercontent.com
   ```

4. **Backend `GOOGLE_CLIENT_ID`**
   Must be exactly the same Web OAuth Client ID.

5. **google-services.json**
   Must belong to the same Firebase/Google project and include your Android app.

## Quick Diagnostic Guide

- Error: `Google sign-in cancelled.`  
  User closed account picker.

- Error: `Google idToken is empty...`  
  Usually wrong/missing Web Client ID or OAuth setup.

- Error: `ApiException 10`  
  Package/SHA/Web client mismatch in Google Console.

- Error from backend: `Invalid Google token`  
  Backend `GOOGLE_CLIENT_ID` does not match frontend token issuer project.

## Recommended Next Test

1. Put real web client ID in run command.
2. Verify backend env `GOOGLE_CLIENT_ID`.
3. Re-run and test one Google account.
4. If failed, use shown snackbar message to identify exact layer (Google SDK vs backend verification).
