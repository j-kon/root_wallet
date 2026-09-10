import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var privacyOverlayView: UIView?
  private var isScreenProtectionEnabled: Bool = true

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    guard isScreenProtectionEnabled else { return }
    showPrivacyOverlay()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    removePrivacyOverlay()
  }

  private func showPrivacyOverlay() {
    guard privacyOverlayView == nil, let window = self.window else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    // Root Wallet Night Pine / Deep Background (#0B0E11)
    overlay.backgroundColor = UIColor(red: 11.0 / 255.0, green: 14.0 / 255.0, blue: 17.0 / 255.0, alpha: 1.0)

    let label = UILabel()
    label.text = "Root Wallet"
    label.textColor = UIColor(red: 236.0 / 255.0, green: 242.0 / 255.0, blue: 238.0 / 255.0, alpha: 1.0)
    label.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
    label.translatesAutoresizingMaskIntoConstraints = false

    overlay.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
    ])

    overlay.tag = 9988
    window.addSubview(overlay)
    privacyOverlayView = overlay
  }

  private func removePrivacyOverlay() {
    privacyOverlayView?.removeFromSuperview()
    privacyOverlayView = nil
    self.window?.viewWithTag(9988)?.removeFromSuperview()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "root_wallet/screen_protection",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "setProtected" {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
          result(false)
          return
        }
        self?.isScreenProtectionEnabled = enabled
        result(true)
        return
      }
      result(FlutterMethodNotImplemented)
    }
  }
}
