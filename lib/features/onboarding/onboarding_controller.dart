import 'package:shared_preferences/shared_preferences.dart';

class OnboardingController {
  static const bool alwaysShowTours = true;
  static const _loginTourSeenKey = 'login_tour_seen';
  static const _signupTourSeenKey = 'signup_tour_seen';
  static const _contactsTourSeenKey = 'contacts_tour_seen';

  static Future<bool> shouldShowLoginTour() async {
    if (alwaysShowTours) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_loginTourSeenKey) ?? false);
  }

  static Future<void> markLoginTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginTourSeenKey, true);
  }

  static Future<void> resetLoginTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginTourSeenKey, false);
  }

  static Future<bool> shouldShowSignupTour() async {
    if (alwaysShowTours) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_signupTourSeenKey) ?? false);
  }

  static Future<void> markSignupTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_signupTourSeenKey, true);
  }

  static Future<void> resetSignupTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_signupTourSeenKey, false);
  }

  static Future<bool> shouldShowContactsTour() async {
    if (alwaysShowTours) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_contactsTourSeenKey) ?? false);
  }

  static Future<void> markContactsTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_contactsTourSeenKey, true);
  }

  static Future<void> resetContactsTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_contactsTourSeenKey, false);
  }
}
