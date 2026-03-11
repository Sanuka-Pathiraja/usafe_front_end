import 'dart:io';

import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'contact_alert_service.dart';

enum PhoneCallLaunchMode {
  direct,
  dialer,
}

class PhoneCallService {
  static Future<PhoneCallLaunchMode> call(String phoneNumber) async {
    final normalizedPhone =
        ContactAlertService.normalizePhoneNumber(phoneNumber);
    if (normalizedPhone.isEmpty) {
      throw Exception('Contact phone number is missing.');
    }

    if (Platform.isAndroid) {
      final permission = await Permission.phone.request();
      if (permission.isGranted) {
        final placedCall =
            await FlutterPhoneDirectCaller.callNumber(normalizedPhone) ?? false;
        if (placedCall) {
          return PhoneCallLaunchMode.direct;
        }
      }
    }

    final dialerUri = Uri(scheme: 'tel', path: normalizedPhone);
    final opened = await launchUrl(
      dialerUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw Exception('Could not open the phone app for this contact.');
    }
    return PhoneCallLaunchMode.dialer;
  }
}
