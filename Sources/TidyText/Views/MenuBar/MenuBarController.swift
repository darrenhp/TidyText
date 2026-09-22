import AppKit
import SwiftUI

public final class MenuBarController: NSObject, NSMenuDelegate {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    private override init() {
        super.init()
    }

    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "TidyText")
            button.toolTip = "TidyText - 选中文字按 ⌥+空格 原位智能整理"
        }

        menu.delegate = self
        statusItem?.menu = menu
        rebuildMenu()
    }

    public func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    public func rebuildMenu() {
        menu.removeAllItems()

        // 1. App Title & Active Model
        let titleItem = NSMenuItem(title: "TidyText 智能文字整理", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let enabledModels = ConfigStorage.shared.getEnabledModelsSortedByPriority()
        let topModelName = enabledModels.first?.displayName ?? "未启用模型"
        let modelStatusItem = NSMenuItem(title: "主用模型: \(topModelName) (共\(enabledModels.count)个就绪)", action: nil, keyEquivalent: "")
        modelStatusItem.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: nil)
        modelStatusItem.isEnabled = false
        menu.addItem(modelStatusItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Prompt Switcher Submenu
        let promptMenu = NSMenu()
        let activePrompt = ConfigStorage.shared.getActivePrompt()
        for prompt in ConfigStorage.shared.prompts {
            let item = NSMenuItem(title: prompt.name, action: #selector(onSelectPrompt(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = prompt.id
            if prompt.id == activePrompt.id {
                item.state = .on
            }
            promptMenu.addItem(item)
        }
        let promptMenuItem = NSMenuItem(title: "当前提示词: \(activePrompt.name)", action: nil, keyEquivalent: "")
        promptMenuItem.image = NSImage(systemSymbolName: "character.book.closed", accessibilityDescription: nil)
        promptMenuItem.submenu = promptMenu
        menu.addItem(promptMenuItem)

        // 3. History Submenu
        let historyMenu = NSMenu()
        let historyItems = HistoryManager.shared.items
        if historyItems.isEmpty {
            let emptyItem = NSMenuItem(title: "暂无整理记录", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            historyMenu.addItem(emptyItem)
        } else {
            for item in historyItems.prefix(10) {
                let preview = item.originalText.prefix(20).replacingOccurrences(of: "\n", with: " ")
                let menuItem = NSMenuItem(
                    title: "\(item.modelName): \"\(preview)...\"",
                    action: #selector(onRestoreHistoryItem(_:)),
                    keyEquivalent: ""
                )
                menuItem.target = self
                menuItem.representedObject = item
                historyMenu.addItem(menuItem)
            }
            historyMenu.addItem(NSMenuItem.separator())
            let clearItem = NSMenuItem(title: "清空历史", action: #selector(onClearHistory), keyEquivalent: "")
            clearItem.target = self
            historyMenu.addItem(clearItem)
        }
        let historyMenuItem = NSMenuItem(title: "最近整理历史", action: nil, keyEquivalent: "")
        historyMenuItem.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
        historyMenuItem.submenu = historyMenu
        menu.addItem(historyMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Action triggers
        let prefs = ConfigStorage.shared.preferences
        let shortcutStr = HotKeyShortcut.displayString(keyCode: prefs.hotKeyKeyCode, modifiers: prefs.hotKeyModifiers)
        let triggerItem = NSMenuItem(title: "立即整理当前选区 (\(shortcutStr))", action: #selector(onTriggerTidy), keyEquivalent: "")
        triggerItem.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
        triggerItem.target = self
        menu.addItem(triggerItem)

        if let button = statusItem?.button {
            button.toolTip = "TidyText - 选中文字按 \(shortcutStr) 原位智能整理"
        }

        let settingsItem = NSMenuItem(title: "设置与模型配置...", action: #selector(onOpenSettings), keyEquivalent: ",")
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Permission status
        if !PermissionsManager.shared.isAccessibilityTrusted {
            let permItem = NSMenuItem(title: "⚠️ 需要辅助功能权限", action: #selector(onOpenPermissions), keyEquivalent: "")
            permItem.target = self
            menu.addItem(permItem)
        }

        menu.addItem(NSMenuItem.separator())

        // 5. Quit
        let quitItem = NSMenuItem(title: "退出 TidyText", action: #selector(onQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func onSelectPrompt(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID {
            ConfigStorage.shared.setActivePrompt(id: id)
            rebuildMenu()
        }
    }

    @objc private func onTriggerTidy() {
        Task {
            await TidyPipeline.shared.triggerTidy()
        }
    }

    @objc private func onOpenSettings() {
        Task { @MainActor in
            SettingsWindowController.shared.show()
        }
    }

    @objc private func onOpenPermissions() {
        PermissionsManager.shared.openAccessibilityPreferences()
    }

    @objc private func onRestoreHistoryItem(_ sender: NSMenuItem) {
        if let item = sender.representedObject as? HistoryItem {
            Task {
                await HistoryManager.shared.restoreOriginal(for: item)
            }
        }
    }

    @objc private func onClearHistory() {
        HistoryManager.shared.clear()
        rebuildMenu()
    }

    @objc private func onQuit() {
        NSApp.terminate(nil)
    }
}
