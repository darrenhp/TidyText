import AppKit
import Carbon

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as menu bar accessory app
        NSApp.setActivationPolicy(.accessory)

        // Initialize Menu Bar UI
        MenuBarController.shared.setup()

        // Setup Global Hotkey (Default Option + Space)
        setupHotKey()

        // Check Accessibility Permissions
        if !PermissionsManager.shared.isAccessibilityTrusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                PermissionsManager.shared.checkAndRequestAccessibility()
            }
        }
    }

    private func setupHotKey() {
        let prefs = ConfigStorage.shared.preferences
        HotKeyManager.shared.register(
            keyCode: prefs.hotKeyKeyCode,
            modifiers: prefs.hotKeyModifiers
        )

        HotKeyManager.shared.onHotKeyPressed = {
            Task {
                await TidyPipeline.shared.triggerTidy()
            }
        }
    }
}
