import 'package:shared_preferences/shared_preferences.dart';

class OnboardingController {
  static const bool alwaysShowTours = false;
  static const _loginTourSeenKey = 'login_tour_v3_seen';
  static const _signupTourSeenKey = 'signup_tour_v3_seen';
  static const _contactsTourSeenKey = 'contacts_tour_seen';
  static const _silentCallTourSeenKey = 'silent_call_tour_seen';
  static const _communityReportTourSeenKey = 'community_report_tour_seen';
  static const _communityMapTourSeenKey = 'community_map_tour_seen';
  static const _safeRouteTourSeenKey = 'safe_route_tour_seen';
  static const _contactsPageTourSeenKey = 'contacts_page_tour_seen';

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

  static Future<bool> shouldShowSilentCallTour() async {
    if (alwaysShowTours) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_silentCallTourSeenKey) ?? false);
  }

  static Future<void> markSilentCallTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_silentCallTourSeenKey, true);
  }

  static Future<void> resetSilentCallTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_silentCallTourSeenKey, false);
  }

  static Future<bool> shouldShowCommunityReportTour() async {
    if (alwaysShowTours) return true;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_communityReportTourSeenKey) ?? false);
  }

  static Future<void> markCommunityReportTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_communityReportTourSeenKey, true);
  }

  static Future<void> resetCommunityReportTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_communityReportTourSeenKey, false);
  }

  static Future<bool> shouldShowCommunityMapTour() async {
    if (alwaysShowTours) return true;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_communityMapTourSeenKey) ?? false);
  }

  static Future<void> markCommunityMapTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_communityMapTourSeenKey, true);
  }

  static Future<void> resetCommunityMapTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_communityMapTourSeenKey, false);
  }

  static Future<bool> shouldShowSafeRouteTour() async {
    if (alwaysShowTours) return true;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_safeRouteTourSeenKey) ?? false);
  }

  static Future<void> markSafeRouteTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_safeRouteTourSeenKey, true);
  }

  static Future<void> resetSafeRouteTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_safeRouteTourSeenKey, false);
  }

  static Future<bool> shouldShowContactsPageTour() async {
    if (alwaysShowTours) return true;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_contactsPageTourSeenKey) ?? false);
  }

  static Future<void> markContactsPageTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_contactsPageTourSeenKey, true);
  }

  static Future<void> resetContactsPageTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_contactsPageTourSeenKey, false);
  }
}
