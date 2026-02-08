import Flutter
import UIKit
import Stripe

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    StripeAPI.defaultPublishableKey = "pk_test_51SwImuLlNAbSbRDVNJv7X5BWmdg3rwURMEfWor7BeXIjSgWx7aKcFBAn1sch1FfH9zWOGTixOvzTFYwYLXjE5sZS00EIhyYGZS"

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
