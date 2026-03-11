import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ MAPBOX PUBLIC TOKEN (REQUIRED FOR MAP DISPLAY)
  MapboxOptions.setAccessToken(
      "pk.eyJ1IjoieW91c3Vmbml6YW0iLCJhIjoiY21tNWEyeWd5MDR4dDJxb20zbndyZjhseCJ9.dz2ioHxFApAW6K0VCfVVMg");

  const platform = MethodChannel('com.usafe_frontend/sos');
  bool isSOS = false;

  try {
    // 1️⃣ Check Overlay Permission
    final bool hasPermission =
        await platform.invokeMethod('checkOverlayPermission');

    if (!hasPermission) {
      await platform.invokeMethod('requestOverlayPermission');
    }

    // 2️⃣ Check SOS Trigger
    isSOS = await platform.invokeMethod<bool>('checkSOSTrigger') ?? false;
  } on PlatformException catch (e) {
    debugPrint("Native Channel Error: ${e.message}");
  }

  runApp(USafeApp(launchedFromSOSWidget: isSOS));
}
