import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:usafe_front_end/src/config/app_config.dart'; // For mapboxPublicToken 
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ MAPBOX PUBLIC TOKEN — loaded from lib/src/config/app_config.dart (gitignored)
  MapboxOptions.setAccessToken(mapboxPublicToken);

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
