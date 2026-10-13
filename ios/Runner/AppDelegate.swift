import Flutter
import UIKit

@main
<<<<<<< HEAD
@objc class AppDelegate: FlutterAppDelegate {
=======
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
>>>>>>> fffc09d (new changes)
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
<<<<<<< HEAD
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
=======
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
>>>>>>> fffc09d (new changes)
}
