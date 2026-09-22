import SwiftUI
import AppKit
import Carbon

public struct ShortcutRecorderView: View {
    @ObservedObject var configStorage: ConfigStorage
    @State private var isRecording: Bool = false
    @State private var validationWarning: String? = nil
    @State private var eventMonitor: Any?

    public init(configStorage: ConfigStorage) {
        self.configStorage = configStorage
    }

    private var currentDisplayString: String {
        let prefs = configStorage.preferences
        return HotKeyShortcut.displayString(keyCode: prefs.hotKeyKeyCode, modifiers: prefs.hotKeyModifiers)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                // Interactive Record Button
                Button(action: {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isRecording ? "record.circle.fill" : "command.square.fill")
                            .foregroundColor(isRecording ? .red : .accentColor)
                            .font(.system(size: 14))

                        if isRecording {
                            Text("请按下按键组合 (按 Esc 取消)...")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                        } else {
                            Text(currentDisplayString)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                        }

                        Text(isRecording ? "等待输入" : "点击修改")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isRecording ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isRecording ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)

                if isRecording {
                    Button("取消") {
                        stopRecording()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if let warning = validationWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // Quick Preset Selection
            VStack(alignment: .leading, spacing: 6) {
                Text("常用推荐快捷键 (点击秒切):")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(HotKeyShortcut.presets) { preset in
                        let isSelected = configStorage.preferences.hotKeyKeyCode == preset.keyCode &&
                                         configStorage.preferences.hotKeyModifiers == preset.modifiers
                        Button(action: {
                            applyPreset(preset)
                        }) {
                            Text(preset.name)
                                .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
                                .foregroundColor(isSelected ? .accentColor : .primary)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        validationWarning = nil

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                DispatchQueue.main.async {
                    self.stopRecording()
                }
                return nil
            }

            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let modifiers = UInt32(flags.rawValue)
            let keyCode = UInt32(event.keyCode)

            if HotKeyShortcut.isValidShortcut(keyCode: keyCode, modifiers: modifiers) {
                DispatchQueue.main.async {
                    HotKeyManager.shared.update(keyCode: keyCode, modifiers: modifiers)
                    MenuBarController.shared.rebuildMenu()
                    self.stopRecording()
                }
                return nil
            } else {
                DispatchQueue.main.async {
                    self.validationWarning = "快捷键必须包含 ⌥ Option、⌘ Command 或 ⌃ Control 修饰键"
                }
                return nil
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func applyPreset(_ preset: PresetShortcut) {
        stopRecording()
        HotKeyManager.shared.update(keyCode: preset.keyCode, modifiers: preset.modifiers)
        MenuBarController.shared.rebuildMenu()
    }
}
