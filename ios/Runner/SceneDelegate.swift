import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // SC-035: oculta el contenido en el selector de aplicaciones (pantallas sensibles).
  override func sceneWillResignActive(_ scene: UIScene) {
    ScreenProtectionState.shared.hide(in: window)
    super.sceneWillResignActive(scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    ScreenProtectionState.shared.reveal()
    super.sceneDidBecomeActive(scene)
  }
}
