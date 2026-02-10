import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const platform = MethodChannel('com.usafe_frontend/sos');
  bool isSOS = false;

  try {
    // 1. Check for Overlay Permission
    final bool hasPermission =
        await platform.invokeMethod('checkOverlayPermission');
    if (!hasPermission) {
      await platform.invokeMethod('requestOverlayPermission');
    }

    // 2. Check for SOS trigger - We pass this to the App root
    isSOS = await platform.invokeMethod<bool>('checkSOSTrigger') ?? false;
  } on PlatformException catch (e) {
    debugPrint("Native Channel Error: ${e.message}");
  }

  runApp(USafeApp(launchedFromSOSWidget: isSOS));
}
