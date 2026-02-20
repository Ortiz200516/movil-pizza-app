import UIKit
import Flutter
import GoogleMaps  // 👈 IMPORTAR ESTO

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 👇 AGREGAR ESTO
    GMSServices.provideAPIKey("AIzaSyAnJpwRt2GBxIto58_jYTDEuYTS1Y6YE0Y")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}