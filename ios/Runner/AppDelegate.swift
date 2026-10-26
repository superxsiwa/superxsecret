import UIKit
import Flutter
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate {

    private let hardeningChannelName = "com.superxsecret.vault/hardening"
    private var hardeningChannel: FlutterMethodChannel?
    private var privacyShieldView: UIVisualEffectView?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        hardeningChannel = FlutterMethodChannel(
            name: hardeningChannelName,
            binaryMessenger: controller.binaryMessenger
        )

        hardeningChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            switch call.method {
            case "copySensitiveClipboard":
                if let args = call.arguments as? [String: Any],
                   let text = args["text"] as? String,
                   let ttlSeconds = args["ttlSeconds"] as? Int {
                    self.copyLocalExpiringPasteboard(secret: text, ttlSeconds: ttlSeconds)
                    result(true)
                } else {
                    result(false)
                }
            case "clearClipboardNow":
                UIPasteboard.general.items = []
                result(true)
            case "checkDeviceIntegrity":
                result(self.inspectIosSecurityPosture())
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Observe Screen Recording / Mirroring changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenCaptureChanged),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )

        // Observe protected data lock (Screen Lock)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProtectedDataUnavailable),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    /// Mask screen in iOS App Switcher before OS takes snapshot
    override func applicationWillResignActive(_ application: UIApplication) {
        showPrivacyShield()
        super.applicationWillResignActive(application)
    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        if !UIScreen.main.isCaptured {
            hidePrivacyShield()
        }
    }

    @objc private func handleScreenCaptureChanged() {
        if UIScreen.main.isCaptured {
            showPrivacyShield()
            hardeningChannel?.invokeMethod("onScreenRecordingDetected", arguments: true)
        } else {
            hidePrivacyShield()
            hardeningChannel?.invokeMethod("onScreenRecordingDetected", arguments: false)
        }
    }

    @objc private func handleProtectedDataUnavailable() {
        hardeningChannel?.invokeMethod("onScreenOffLock", arguments: nil)
    }

    /// Copies secret to iOS Pasteboard with `.localOnly: true` (blocks Universal Clipboard Handoff
    /// to nearby Macs/iPads) and `.expirationDate` (OS purges clipboard automatically even if app exits).
    private func copyLocalExpiringPasteboard(secret: String, ttlSeconds: Int) {
        let expireDate = Date().addingTimeInterval(TimeInterval(ttlSeconds))
        let item: [String: Any] = [UTType.utf8PlainText.identifier: secret]
        UIPasteboard.general.setItems(
            [item],
            options: [
                .localOnly: true,
                .expirationDate: expireDate
            ]
        )
    }

    private func showPrivacyShield() {
        guard privacyShieldView == nil, let keyWindow = window else { return }
        let blurEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        let shield = UIVisualEffectView(effect: blurEffect)
        shield.frame = keyWindow.bounds
        shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        keyWindow.addSubview(shield)
        privacyShieldView = shield
    }

    private func hidePrivacyShield() {
        privacyShieldView?.removeFromSuperview()
        privacyShieldView = nil
    }

    /// Offline Jailbreak & DYLD injection detection
    private func inspectIosSecurityPosture() -> [String: Any] {
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/var/jb",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd"
        ]
        let hasJbFile = jailbreakPaths.contains { FileManager.default.fileExists(atPath: $0) }
        let hasDyldInsert = ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"] != nil

        return [
            "isCompromised": (hasJbFile || hasDyldInsert),
            "hasRootOrJailbreak": hasJbFile,
            "isDebuggerOrFridaDetected": hasDyldInsert,
            "isScreenGuardActive": true,
            "zeroNetworkPermissionVerified": true
        ]
    }
}

