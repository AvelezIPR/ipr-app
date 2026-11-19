import Flutter
import UIKit

/// SC-035: vista de privacidad al pasar a segundo plano en las pantallas
/// sensibles. Dart la activa/desactiva con el canal `co.ipr.app/screen_protection`.
/// El estado vive aquí y la superposición la pinta `SceneDelegate` (la app usa UIScene).
final class ScreenProtectionState {
  static let shared = ScreenProtectionState()
  var enabled = false
  private var overlay: UIView?

  func hide(in window: UIWindow?) {
    guard enabled, let window = window, overlay == nil else { return }
    let view = UIView(frame: window.bounds)
    view.backgroundColor = .white
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(view)
    overlay = view
  }

  func reveal() {
    overlay?.removeFromSuperview()
    overlay = nil
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "co.ipr.app.screen_protection") {
      let channel = FlutterMethodChannel(
        name: "co.ipr.app/screen_protection",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "enable":
          ScreenProtectionState.shared.enabled = true
          result(nil)
        case "disable":
          ScreenProtectionState.shared.enabled = false
          ScreenProtectionState.shared.reveal()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
