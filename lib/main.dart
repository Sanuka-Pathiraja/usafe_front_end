import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';

Future<void> main() async {
  // Required for interacting with the native platform before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // This must match the string in your MainActivity.kt
  const platform = MethodChannel('com.usafe_frontend/sos');

  bool isSOS = false;

  try {
    // 1. Check for Overlay Permission (Display over other apps)
    // This allows the app to pop up even if the phone is locked
    final bool hasPermission =
        await platform.invokeMethod('checkOverlayPermission');
    if (!hasPermission) {
      await platform.invokeMethod('requestOverlayPermission');
    }

    // 2. Check if the app was launched via the SOS trigger
    // This reads the SharedPreferences flag we set in Kotlin
    isSOS = await platform.invokeMethod<bool>('checkSOSTrigger') ?? false;
  } on PlatformException catch (e) {
    debugPrint("Native Channel Error: ${e.message}");
  }

  // Pass the result into the App root
  runApp(USafeApp(launchedFromSOSWidget: isSOS));
}
