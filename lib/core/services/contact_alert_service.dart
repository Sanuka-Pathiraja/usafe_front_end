import 'package:usafe_front_end/features/auth/auth_service.dart';

class ContactAlertService {
  static const String defaultEmergencyMessage =
      'This is an emergency. I may need help. Please contact me immediately or check my location.';

  static String normalizePhoneNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      final char = trimmed[i];
      final isLeadingPlus = char == '+' && buffer.isEmpty;
      final isDigit = char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
      if (isLeadingPlus || isDigit) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  static Future<String> sendEmergencyMessage({
    String? contactId,
    required String phoneNumber,
    required String message,
  }) async {
    final normalizedPhone = normalizePhoneNumber(phoneNumber);
    final trimmedMessage = message.trim();

    if (normalizedPhone.isEmpty) {
      throw Exception('Contact phone number is missing.');
    }
    if (trimmedMessage.isEmpty) {
      throw Exception('Emergency message cannot be empty.');
    }

    final response = await AuthService.sendContactAlert(
      contactId: contactId,
      phoneNumber: normalizedPhone,
      message: trimmedMessage,
    );
    return (response['message'] ?? 'Emergency alert sent successfully.')
        .toString();
  }
}
