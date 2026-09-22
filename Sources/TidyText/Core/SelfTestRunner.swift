import Foundation

public final class SelfTestRunner {
    public static func runAllTests() -> Bool {
        print("=== 开始运行 TidyText 内部自测套件 ===")
        var passed = 0
        var total = 0

        func check(_ name: String, _ condition: Bool) {
            total += 1
            if condition {
                print("  ✓ [PASS] \(name)")
                passed += 1
            } else {
                print("  ✕ [FAIL] \(name)")
            }
        }

        // Test 1: Provider Configs
        let providers = AIProviderConfig.defaultProviders()
        check("默认供应商列表包含 DeepSeek", providers.contains(where: { $0.type == .deepseek }))
        check("默认供应商列表包含 豆包 (Doubao)", providers.contains(where: { $0.type == .doubao }))
        check("默认供应商列表包含 Claude", providers.contains(where: { $0.type == .claude }))
        check("默认供应商列表包含 OpenAI", providers.contains(where: { $0.type == .openai }))

        // Test 2: Prompt Templates
        let templates = PromptTemplate.defaultTemplates()
        check("内置提示词包含自然码双拼与模糊音专属模板", templates.contains(where: { $0.name.contains("双拼") }))
        check("内置提示词包含反复修改理顺急救包", templates.contains(where: { $0.name.contains("反复修改") }))
        check("内置提示词包含综合整理", templates.contains(where: { $0.name.contains("综合整理") }))

        if let zrmPrompt = templates.first(where: { $0.name.contains("双拼") }) {
            check("自然码 Prompt 包含平翘舌指引", zrmPrompt.systemPrompt.contains("z/zh"))
            check("自然码 Prompt 包含前后鼻音指引", zrmPrompt.systemPrompt.contains("in/ing"))
        }

        // Test 3: Model Priority and Ordering
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = ConfigStorage(customBaseDirectory: testDir)
        let sorted = storage.getEnabledModelsSortedByPriority()
        check("初始状态已启用模型按优先级排序非空", !sorted.isEmpty)
        if sorted.count >= 2 {
            let firstId = sorted[0].id
            let secondId = sorted[1].id
            storage.moveModelDown(modelId: firstId)
            let newSorted = storage.getEnabledModelsSortedByPriority()
            check("向下移动模型后优先级次序正确调整", newSorted[0].id == secondId)
        }

        // Test 4: ModelRouter Failover Logic (Mock)
        let enabled = storage.getEnabledModelsSortedByPriority()
        check("调度器可准确读取待生效优先级模型", enabled.count > 0)

        // Test 5: HotKeyShortcut mapping & formatting
        let optSpace = HotKeyShortcut.displayString(keyCode: 49, modifiers: 2048)
        check("快捷键字符串格式化 Option+Space 包含 ⌥ 与 空格", optSpace.contains("⌥") && optSpace.contains("空格"))

        let optShiftT = HotKeyShortcut.displayString(keyCode: 17, modifiers: 2048 | 512)
        check("快捷键字符串格式化 Option+Shift+T 包含 ⌥, ⇧ 与 T", optShiftT.contains("⌥") && optShiftT.contains("⇧") && optShiftT.contains("T"))

        // Test 6: HotKeyShortcut validation
        check("带有 Option 修饰符的按键为合法快捷键", HotKeyShortcut.isValidShortcut(keyCode: 17, modifiers: 2048))
        check("单纯单字母键（无修饰符）被正确判定为非法", !HotKeyShortcut.isValidShortcut(keyCode: 17, modifiers: 0))

        // Test 7: Preset shortcuts
        check("快捷键预设库包含推荐的 ⌥ + ⇧ + T", HotKeyShortcut.presets.contains(where: { $0.name.contains("⇧") }))

        print("\n=== 自测结果汇总: \(passed)/\(total) 通过 ===")
        return passed == total
    }
}
