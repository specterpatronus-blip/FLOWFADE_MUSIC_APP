import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let flutterViewController = window?.rootViewController as? FlutterViewController else {
      print("SceneDelegate: FlutterViewController not available, audio channel setup skipped.")
      return
    }

    AudioEngineManager.shared.setup(with: flutterViewController.binaryMessenger)
    print("SceneDelegate: Audio channel configured from SceneDelegate.")
  }
}
