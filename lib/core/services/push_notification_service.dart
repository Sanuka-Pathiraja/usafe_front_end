import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usafe_front_end/core/services/app_navigation_service.dart';
import 'package:usafe_front_end/widgets/sos_screen.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _backendUrl = 'http://10.0.2.2:5000';
  static const String _authTokenKey = 'auth_token';
  static const String _legacyTokenKey = 'token';
  static const String _channelId = 'usafe_emergency_alerts';
  static const String _channelName = 'USafe Emergency Alerts';
  static const String _channelDescription =
      'Critical alerts for low safety score and emergency flows.';
  static const String _cachedPushTokenKey = 'push_notification_token';
  static const String _pendingPayloadKey = 'pending_push_payload';

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    await _initializeLocalNotifications();
    await _requestPermissions();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
    _messaging.onTokenRefresh.listen((token) async {
      await _cachePushToken(token);
      await syncTokenWithBackend();
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _storePendingPayload(_normalizedPayload(initialMessage));
    }

    final token = await _messaging.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await _cachePushToken(token);
    }

    _initialized = true;
  }

  static Future<void> initializeBackgroundRuntime() async {
    if (_initialized) return;
    await _initializeLocalNotifications();
    _initialized = true;
  }

  static Future<void> syncTokenWithBackend() async {
    final pushToken = await _currentPushToken();
    final authToken = await _currentAuthToken();
    if (pushToken.isEmpty || authToken.isEmpty) return;

    final payload = <String, dynamic>{
      'token': pushToken,
      'platform': _platformLabel,
    };

    const endpoints = <String>[
      '/notification/device-token',
      '/notifications/device-token',
      '/user/device-token',
      '/push/device-token',
    ];

    for (final path in endpoints) {
      try {
        final resp = await http.post(
          Uri.parse('$_backendUrl$path'),
          headers: <String, String>{
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );

        if (resp.statusCode == 404 || resp.statusCode == 405) {
          continue;
        }
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          debugPrint('[PushNotification] Token registered via $path');
          return;
        }

        debugPrint(
          '[PushNotification] Token register failed via $path: ${resp.statusCode} ${resp.body}',
        );
        return;
      } catch (e) {
        debugPrint('[PushNotification] Token register error via $path: $e');
        return;
      }
    }

    debugPrint('[PushNotification] No device-token endpoint available yet');
  }

  static Future<void> unregisterTokenFromBackend() async {
    final pushToken = await _currentPushToken();
    final authToken = await _currentAuthToken();
    if (pushToken.isEmpty || authToken.isEmpty) return;

    const endpoints = <String>[
      '/notification/device-token',
      '/notifications/device-token',
      '/user/device-token',
      '/push/device-token',
    ];

    for (final path in endpoints) {
      try {
        final resp = await http.delete(
          Uri.parse('$_backendUrl$path'),
          headers: <String, String>{
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{'token': pushToken}),
        );

        if (resp.statusCode == 404 || resp.statusCode == 405) {
          continue;
        }
        return;
      } catch (_) {
        return;
      }
    }
  }

  static Future<void> processPendingLaunchPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingPayloadKey) ?? '';
    if (raw.trim().isEmpty) return;

    await prefs.remove(_pendingPayloadKey);

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _routeFromPayload(decoded);
      } else if (decoded is Map) {
        _routeFromPayload(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('[PushNotification] Pending payload parse failed: $e');
    }
  }

  static Future<void> showLocalLowSafetyNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        playSound: true,
        ticker: 'USafe emergency alert',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: jsonEncode(payload),
    );
  }

  static Future<void> _initializeLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final raw = response.payload ?? '';
        if (raw.trim().isEmpty) return;

        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            _routeFromPayload(decoded);
          } else if (decoded is Map) {
            _routeFromPayload(Map<String, dynamic>.from(decoded));
          }
        } catch (e) {
          debugPrint('[PushNotification] Invalid notification payload: $e');
        }
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
      ),
    );
  }

  static Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final payload = _normalizedPayload(message);
    final type = (payload['type'] ?? '').toString();
    if (type != 'low_safety_score') {
      debugPrint(
        '[PushNotification] Ignoring foreground notification with type=$type',
      );
      return;
    }
    final title = message.notification?.title ??
        'Safety Score Is Low';
    final body = message.notification?.body ??
        'Safety score is below 40. Tap here to activate SOS.';

    await showLocalLowSafetyNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }

  static Future<void> _handleMessageTap(RemoteMessage message) async {
    _routeFromPayload(_normalizedPayload(message));
  }

  static Map<String, dynamic> _normalizedPayload(RemoteMessage message) {
    final payload = Map<String, dynamic>.from(message.data);
    if (!payload.containsKey('type') &&
        (message.notification?.title ?? '').toLowerCase().contains('safety')) {
      payload['type'] = 'low_safety_score';
    }
    return payload;
  }

  static void _routeFromPayload(Map<String, dynamic> payload) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final type = (payload['type'] ?? '').toString().trim().toLowerCase();
    switch (type) {
      case 'low_safety_score':
        navigator.push(
          MaterialPageRoute(
            builder: (_) => const SOSScreen(
              autoStart: true,
              triggerSource: 'low-safety-score-notification',
            ),
          ),
        );
        return;
      default:
        return;
    }
  }

  static Future<void> _cachePushToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedPushTokenKey, token);
  }

  static Future<String> _currentPushToken() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cachedPushTokenKey) ?? '';
    if (cached.trim().isNotEmpty) {
      return cached.trim();
    }

    final token = await _messaging.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await _cachePushToken(token);
      return token.trim();
    }
    return '';
  }

  static Future<String> _currentAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_authTokenKey) ?? prefs.getString(_legacyTokenKey) ?? '')
        .trim();
  }

  static Future<void> _storePendingPayload(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingPayloadKey, jsonEncode(payload));
  }

  static String get _platformLabel {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PushNotificationService.initializeBackgroundRuntime();
  final payload = Map<String, dynamic>.from(message.data);
  final type = (payload['type'] ?? '').toString();
  if (type != 'low_safety_score') {
    debugPrint(
      '[PushNotification] Ignoring background notification with type=$type',
    );
    return;
  }
  final title = message.notification?.title ??
      'Safety Score Is Low';
  final body = message.notification?.body ??
      'Safety score is below 40. Tap here to activate SOS.';

  await PushNotificationService.showLocalLowSafetyNotification(
    title: title,
    body: body,
    payload: payload,
  );
}
