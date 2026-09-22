import Foundation
import Carbon
import AppKit

public final class HotKeyManager {
    public static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    public var onHotKeyPressed: (() -> Void)?

    private init() {
        setupCarbonEventHandler()
    }

    deinit {
        unregister()
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func setupCarbonEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerBlock: EventHandlerUPP = { _, event, _ -> OSStatus in
            HotKeyManager.shared.onHotKeyPressed?()
            return noErr
        }

        InstallEventHandler(
            GetEventDispatcherTarget(),
            handlerBlock,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }

    public private(set) var currentKeyCode: UInt32 = 49
    public private(set) var currentModifiers: UInt32 = 2048

    public func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()
        self.currentKeyCode = keyCode
        self.currentModifiers = modifiers

        let hotKeyID = EventHotKeyID(
            signature: OSType(0x54445458), // "TDTX"
            id: 1
        )

        // Convert Cocoa / Carbon modifier flags
        let carbonModifiers = carbonModifierFlags(from: modifiers)

        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("[HotKeyManager] Failed to register hotkey, status: \(status)")
        }
    }

    public func update(keyCode: UInt32, modifiers: UInt32) {
        register(keyCode: keyCode, modifiers: modifiers)
        ConfigStorage.shared.preferences.hotKeyKeyCode = keyCode
        ConfigStorage.shared.preferences.hotKeyModifiers = modifiers
        ConfigStorage.shared.save()
    }

    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func carbonModifierFlags(from flags: UInt32) -> UInt32 {
        var result: UInt32 = 0
        if (flags & 2048) != 0 || (flags & UInt32(NSEvent.ModifierFlags.option.rawValue)) != 0 {
            result |= UInt32(optionKey)
        }
        if (flags & 4096) != 0 || (flags & UInt32(NSEvent.ModifierFlags.command.rawValue)) != 0 {
            result |= UInt32(cmdKey)
        }
        if (flags & 1024) != 0 || (flags & UInt32(NSEvent.ModifierFlags.control.rawValue)) != 0 {
            result |= UInt32(controlKey)
        }
        if (flags & 512) != 0 || (flags & UInt32(NSEvent.ModifierFlags.shift.rawValue)) != 0 {
            result |= UInt32(shiftKey)
        }
        if result == 0 {
            result = UInt32(optionKey) // Fallback default
        }
        return result
    }
}
