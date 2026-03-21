import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:usafe_front_end/main.dart' as app;
import 'package:usafe_front_end/src/pages/home_screen.dart';
import 'package:usafe_front_end/src/pages/emergency_process_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('USafe navigation timing benchmark', (WidgetTester tester) async {
    // ── Step 1: run full startup so all services (Firebase, Supabase) init ──
    app.main();
    await tester.pump(const Duration(seconds: 12));

    // ── Step 2: replace UI with HomeScreen directly ───────────────────────
    // Services are initialized; bypassing login for pure navigation timing.
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(seconds: 2));

    final results = <String, int>{};

    // ── Helper: go back using the iOS-style back arrow your app uses ─────
    Future<void> goBack() async {
      final backIcon = find.byIcon(Icons.arrow_back_ios_new_rounded);
      if (backIcon.evaluate().isNotEmpty) {
        await tester.tap(backIcon.first);
      } else {
        final anyBack = find.byIcon(Icons.arrow_back);
        if (anyBack.evaluate().isNotEmpty) {
          await tester.tap(anyBack.first);
        }
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    // ── Helper: measure time from tap to first rendered frame ─────────────
    Future<void> measure(String label, Finder target) async {
      if (target.evaluate().isEmpty) {
        debugPrint('⚠ Skipped (widget not found): $label');
        return;
      }
      final sw = Stopwatch()..start();
      await tester.tap(target.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      sw.stop();
      results[label] = sw.elapsedMilliseconds;
      debugPrint('⏱ $label: ${sw.elapsedMilliseconds}ms');
    }

    // ════════════════════════════════════════════════════
    //  SECTION 1 — Bottom tab navigation from Home
    // ════════════════════════════════════════════════════

    await measure('Home → Score tab',    find.text('Score'));
    await measure('Score tab → Contacts tab', find.text('Contacts'));
    await measure('Contacts tab → Profile tab', find.text('Profile'));
    await measure('Profile tab → Home (SOS) tab', find.text('SOS'));

    // ════════════════════════════════════════════════════
    //  SECTION 2 — Push navigations from Safety Score tab
    // ════════════════════════════════════════════════════

    // Go to Score tab and wait for SafetyScoreScreen to render its buttons
    await tester.tap(find.text('Score'));
    await tester.pump(const Duration(seconds: 5));

    await measure('Score → Safepath Navigation', find.text('Safepath Navigation'));
    await goBack();
    await tester.pump(const Duration(seconds: 5)); // reload score screen

    await measure('Score → Safepath Guardian', find.text('Safepath Guardian'));
    await goBack();
    await tester.pump(const Duration(milliseconds: 500));

    // ════════════════════════════════════════════════════
    //  SECTION 3 — Safety Score Details from Home tab
    // ════════════════════════════════════════════════════

    await tester.tap(find.text('SOS'));
    await tester.pump(const Duration(seconds: 1));

    // The status pill shows a label ('Checking', 'SAFE', 'CAUTION', 'HIGH RISK')
    const statusLabels = ['Checking', 'SAFE', 'CAUTION', 'HIGH RISK', 'CRITICAL'];
    for (final label in statusLabels) {
      if (find.text(label).evaluate().isNotEmpty) {
        await measure('Home → Safety Score Details', find.text(label).first);
          await goBack();
        break;
      }
    }

    // ════════════════════════════════════════════════════
    //  SECTION 4 — Emergency Process Screen first frame
    //  (measured in isolation — SOS hold animation excluded)
    // ════════════════════════════════════════════════════

    final emergencySw = Stopwatch()..start();
    await tester.pumpWidget(
      const MaterialApp(
        home: EmergencyProcessScreen(
          contactAuthoritiesDuringEmergency: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    emergencySw.stop();
    results['Emergency Screen first frame'] = emergencySw.elapsedMilliseconds;
    debugPrint('⏱ Emergency Screen first frame: ${emergencySw.elapsedMilliseconds}ms');

    // ════════════════════════════════════════════════════
    //  FINAL REPORT
    // ════════════════════════════════════════════════════

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('   USafe Navigation Benchmark Results');
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('');
    debugPrint('  TAB NAVIGATION (IndexedStack)');
    const tabKeys = [
      'Home → Score tab',
      'Score tab → Contacts tab',
      'Contacts tab → Profile tab',
      'Profile tab → Home (SOS) tab',
    ];
    for (final k in tabKeys) {
      if (results.containsKey(k)) {
        debugPrint('    ${k.padRight(38)}: ${results[k]}ms');
      }
    }
    debugPrint('');
    debugPrint('  PUSH NAVIGATION (from Score screen)');
    const pushKeys = [
      'Score → Safepath Navigation',
      'Score → Safepath Guardian',
    ];
    for (final k in pushKeys) {
      if (results.containsKey(k)) {
        debugPrint('    ${k.padRight(38)}: ${results[k]}ms');
      }
    }
    debugPrint('');
    debugPrint('  OTHER');
    const otherKeys = [
      'Home → Safety Score Details',
      'Emergency Screen first frame',
    ];
    for (final k in otherKeys) {
      if (results.containsKey(k)) {
        debugPrint('    ${k.padRight(38)}: ${results[k]}ms');
      }
    }
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════');
  });
}
