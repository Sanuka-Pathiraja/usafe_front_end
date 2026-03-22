import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:usafe_front_end/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('USafe startup time benchmark', (WidgetTester tester) async {
    final totalStopwatch = Stopwatch()..start();

    // Launch the app
    app.main();

    // Wait for the very first frame (splash screen appears)
    await tester.pump();
    final firstFrameMs = totalStopwatch.elapsedMilliseconds;
    debugPrint('⏱ First frame rendered: ${firstFrameMs}ms');

    // Wait for splash screen to settle
    await tester.pump(const Duration(milliseconds: 500));
    final splashVisibleMs = totalStopwatch.elapsedMilliseconds;
    debugPrint('⏱ Splash screen visible: ${splashVisibleMs}ms');

    // Wait for splash to finish and navigate to Login or Home.
    // Splash has a 2.5s delay + up to 8s session validation timeout.
    await tester.pumpAndSettle(const Duration(seconds: 15));
    totalStopwatch.stop();

    final totalMs = totalStopwatch.elapsedMilliseconds;
    debugPrint('⏱ Navigation from splash completed: ${totalMs}ms');

    debugPrint('');
    debugPrint('========================================');
    debugPrint('  USafe Startup Benchmark Results');
    debugPrint('========================================');
    debugPrint('  First frame          : ${firstFrameMs}ms');
    debugPrint('  Splash visible       : ${splashVisibleMs}ms');
    debugPrint('  Full startup (total) : ${totalMs}ms  (${(totalMs / 1000).toStringAsFixed(2)}s)');
    debugPrint('========================================');

    // Test completes — timing results printed above.
  });
}
