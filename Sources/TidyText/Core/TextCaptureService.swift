import Foundation
import AppKit
import ApplicationServices
import Carbon

public final class TextCaptureService {
    public static let shared = TextCaptureService()

    private init() {}

    /// Captures selected text from current frontmost application
    /// Priority 1: Accessibility API (non-destructive)
    /// Priority 2: Synthetic Cmd+C simulation fallback
    public func captureSelectedText() async -> String? {
        if let axText = captureViaAccessibility(), !axText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return axText
        }
        return await captureViaClipboardSimulation()
    }

    public func captureViaAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElementValue: AnyObject?
        let status = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElementValue)

        guard status == .success, let element = focusedElementValue else {
            return nil
        }

        let focusedElement = element as! AXUIElement
        var selectedTextValue: AnyObject?
        let textStatus = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)

        if textStatus == .success, let text = selectedTextValue as? String, !text.isEmpty {
            return text
        }
        return nil
    }

    public func captureViaClipboardSimulation() async -> String? {
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount

        // Simulate Cmd+C
        postKeyCombination(keyCode: CGKeyCode(kVK_ANSI_C), modifiers: .maskCommand)

        // Wait up to 200ms for pasteboard update
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
            if pasteboard.changeCount != initialChangeCount {
                if let string = pasteboard.string(forType: .string), !string.isEmpty {
                    return string
                }
            }
        }

        // Fallback: check if pasteboard already has content
        if let string = pasteboard.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return string
        }

        return nil
    }

    private func postKeyCombination(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = modifiers
        keyDown?.post(tap: .cghidEventTap)

        Thread.sleep(forTimeInterval: 0.01)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = modifiers
        keyUp?.post(tap: .cghidEventTap)
    }
}
