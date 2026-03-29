import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/app_navigation_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'src/pages/splash_screen.dart';
import 'widgets/sos_screen.dart';

class USafeApp extends StatefulWidget {
  const USafeApp({super.key});

  @override
  State<USafeApp> createState() => _USafeAppState();
}

class _USafeAppState extends State<USafeApp> with WidgetsBindingObserver {
  static const MethodChannel _sosChannel =
      MethodChannel('com.usafe_frontend/sos');
  bool _handlingSos = false;
  static const int _sosTriggerWindowMs = 30 * 1000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sosChannel.setMethodCallHandler(_handleSosMethodCall);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.processPendingLaunchPayload();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sosChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSosTrigger();
    }
  }

  Future<void> _handleSosMethodCall(MethodCall call) async {
    if (call.method == 'sosTriggered') {
      final source = call.arguments is String ? call.arguments as String : null;
      debugPrint('SOS: methodChannel sosTriggered source=$source');
      await _startSosFlow(source: source);
    }
  }

  Future<void> _startSosFlow({String? source}) async {
    if (_handlingSos) return;
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    _handlingSos = true;
    final resolvedSource = await _resolveSosSource(source);
    await nav.push(
      MaterialPageRoute(
        builder: (_) =>
            SOSScreen(autoStart: true, triggerSource: resolvedSource),
      ),
    );
    _handlingSos = false;
  }

  Future<String> _resolveSosSource(String? source) async {
    final direct = (source ?? '').trim();
    if (direct.isNotEmpty) return direct;

    final prefs = await SharedPreferences.getInstance();
    final fallback =
        prefs.getString('flutter.SOS_TRIGGER_SOURCE') ??
            prefs.getString('SOS_TRIGGER_SOURCE') ??
            'notification';
    debugPrint('SOS: prefs fallback source=$fallback');
    await prefs.remove('SOS_TRIGGER_SOURCE');
    await prefs.remove('flutter.SOS_TRIGGER_SOURCE');
    return fallback;
  }

  Future<void> _checkSosTrigger() async {
    if (_handlingSos) return;
    final prefs = await SharedPreferences.getInstance();
    final triggered = prefs.getBool('SOS_TRIGGERED') ??
        prefs.getBool('flutter.SOS_TRIGGERED') ??
        false;
    if (!triggered) return;

    final ts = prefs.getInt('SOS_TRIGGERED_TS') ??
        prefs.getInt('flutter.SOS_TRIGGERED_TS') ??
        0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (ts <= 0 || (now - ts) > _sosTriggerWindowMs) {
      await prefs.setBool('SOS_TRIGGERED', false);
      await prefs.setBool('flutter.SOS_TRIGGERED', false);
      await prefs.setInt('SOS_TRIGGERED_TS', 0);
      await prefs.setInt('flutter.SOS_TRIGGERED_TS', 0);
      return;
    }

    await prefs.setBool('SOS_TRIGGERED', false);
    await prefs.setBool('flutter.SOS_TRIGGERED', false);
    await prefs.setInt('SOS_TRIGGERED_TS', 0);
    await prefs.setInt('flutter.SOS_TRIGGERED_TS', 0);

    await _startSosFlow();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USafe',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,

      // Injecting the new Design System
      theme: AppTheme.darkTheme, // 👉 Locks in the new Master Theme
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,

      // Keeping the original skeleton logic
      home: const SplashScreen(),
    );
  }
}
