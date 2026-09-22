import Foundation
import AppKit
import ApplicationServices
import Carbon

public final class TextReplaceService {
    public static let shared = TextReplaceService()

    private init() {}

    /// In-place replaces the currently selected text in the active application
    /// Priority 1: Accessibility API direct attribute replacement (instant, zero clipboard change)
    /// Priority 2: Clipboard paste simulation via synthetic Cmd+V
    @discardableResult
    public func replaceSelectedText(with replacementText: String) async -> Bool {
        if replaceViaAccessibility(with: replacementText) {
            return true
        }
        return await replaceViaClipboardSimulation(with: replacementText)
    }

    public func replaceViaAccessibility(with text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElementValue: AnyObject?
        let status = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElementValue)

        guard status == .success, let element = focusedElementValue else {
            return false
        }

        let focusedElement = element as! AXUIElement
        var isSettable: DarwinBoolean = false
        let settableStatus = AXUIElementIsAttributeSettable(focusedElement, kAXSelectedTextAttribute as CFString, &isSettable)

        if settableStatus == .success && isSettable.boolValue {
            let setStatus = AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
            return setStatus == .success
        }

        return false
    }

    public func replaceViaClipboardSimulation(with text: String) async -> Bool {
        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)

        // Write new text to pasteboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure clipboard registered
        try? await Task.sleep(nanoseconds: 30_000_000) // 30ms

        // Simulate Cmd+V
        postKeyCombination(keyCode: CGKeyCode(kVK_ANSI_V), modifiers: .maskCommand)

        // Restore clipboard after a brief moment if needed
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms
            if let old = previousString, pasteboard.string(forType: .string) == text {
                pasteboard.clearContents()
                pasteboard.setString(old, forType: .string)
            }
        }

        return true
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
