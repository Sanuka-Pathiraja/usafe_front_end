class Validators {
  static bool isValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  static bool isStrongPassword(String value) {
    if (value.length < 6) return false;
    return true;
  }
}
