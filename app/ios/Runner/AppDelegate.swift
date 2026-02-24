import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Replace MAPS_API_KEY_PLACEHOLDER with the actual Maps API key before building.
    GMSServices.provideAPIKey("AIzaSyCAYMEtWprgOA4q1rCSVN8K0DbL3gH8Oug")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
