import Foundation
import AppKit
import ApplicationServices

public final class PermissionsManager {
    public static let shared = PermissionsManager()

    private init() {}

    public var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public func checkAndRequestAccessibility() -> Bool {
        if isAccessibilityTrusted {
            return true
        }

        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        return AXIsProcessTrustedWithOptions(options)
    }

    public func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
