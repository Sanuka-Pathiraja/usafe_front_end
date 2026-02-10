import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants/app_colors.dart';
import 'src/pages/splash_screen.dart';
import 'widgets/sos_screen.dart';

// 🚨 Add this Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class USafeApp extends StatefulWidget {
  final bool launchedFromSOSWidget;

  const USafeApp({super.key, this.launchedFromSOSWidget = false});

  @override
  State<USafeApp> createState() => _USafeAppState();
}

class _USafeAppState extends State<USafeApp> {
  static const platform = MethodChannel('com.usafe_frontend/sos');

  @override
  void initState() {
    super.initState();
    // Listen for SOS triggers while the app is already open
    _setupSOSListener();
  }

  void _setupSOSListener() {
    // We check every time the app comes back to life
    SystemChannels.lifecycle.setMessageHandler((msg) async {
      if (msg == AppLifecycleState.resumed.toString()) {
        final bool? isEmergency =
            await platform.invokeMethod<bool>('checkSOSTrigger');
        if (isEmergency == true) {
          _navigateToSOS();
        }
      }
      return null;
    });
  }

  void _navigateToSOS() {
    // 🚨 This forces the app to jump to the SOS Screen no matter where you are
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SOSScreen(autoStart: true)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 🚨 Assign the key here
      title: 'USafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: SplashScreen(launchedFromSOSWidget: widget.launchedFromSOSWidget),
    );
  }
}
