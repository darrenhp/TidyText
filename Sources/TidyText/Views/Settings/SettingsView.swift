import SwiftUI

public struct SettingsView: View {
    @ObservedObject var configStorage = ConfigStorage.shared
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            ModelPrioritySettingsView(configStorage: configStorage)
                .tabItem {
                    Label("模型与优先级", systemImage: "arrow.up.arrow.down.square")
                }
                .tag(0)

            ProviderSettingsView(configStorage: configStorage)
                .tabItem {
                    Label("供应商配置", systemImage: "server.rack")
                }
                .tag(1)

            PromptSettingsView(configStorage: configStorage)
                .tabItem {
                    Label("提示词模板", systemImage: "character.book.closed")
                }
                .tag(2)

            GeneralSettingsView(configStorage: configStorage)
                .tabItem {
                    Label("通用设置", systemImage: "gearshape")
                }
                .tag(3)
        }
        .frame(width: 760, height: 540)
        .padding(16)
    }
}

// MARK: - Tab 1: 模型与优先级设置
struct ModelPrioritySettingsView: View {
    @ObservedObject var configStorage: ConfigStorage
    @State private var showingAddModelSheet = false
    @State private var testStatusMap: [UUID: String] = [:]

    var sortedModels: [ModelConfig] {
        configStorage.models.sorted { $0.priority < $1.priority }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("模型优先级与自动故障转移 (Failover)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("系统将优先调用顺位最高的启用模型；若遇限流 (429) 或网络超时，将自动降级至后续备用模型。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { showingAddModelSheet = true }) {
                    Label("添加模型", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            List {
                ForEach(Array(sortedModels.enumerated()), id: \.element.id) { index, model in
                    HStack(spacing: 12) {
                        // Priority Badge
                        VStack {
                            Text(index == 0 ? "主用" : "备用")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(index == 0 ? .green : .secondary)
                            Text("#\(index + 1)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 36)

                        // Provider Icon & Name
                        let prov = configStorage.getProvider(for: model)
                        Image(systemName: prov?.type.iconName ?? "cube")
                            .foregroundColor(.accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(model.displayName)
                                    .fontWeight(.medium)
                                if !(prov?.apiKey.isEmpty ?? true) {
                                    Text("已配置 Key")
                                        .font(.system(size: 9))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundColor(.green)
                                        .cornerRadius(3)
                                } else {
                                    Text("未填 Key")
                                        .font(.system(size: 9))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundColor(.orange)
                                        .cornerRadius(3)
                                }
                            }
                            Text("\(prov?.name ?? "未知") · \(model.modelIdentifier)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Test Status
                        if let status = testStatusMap[model.id] {
                            Text(status)
                                .font(.caption2)
                                .foregroundColor(status.contains("✓") ? .green : .red)
                        }

                        // Test Button
                        Button("测试") {
                            testModel(model)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)

                        // Up / Down Priority Buttons
                        HStack(spacing: 2) {
                            Button(action: { configStorage.moveModelUp(modelId: model.id) }) {
                                Image(systemName: "arrow.up")
                            }
                            .disabled(index == 0)

                            Button(action: { configStorage.moveModelDown(modelId: model.id) }) {
                                Image(systemName: "arrow.down")
                            }
                            .disabled(index == sortedModels.count - 1)
                        }
                        .buttonStyle(.borderless)

                        // Enable Switch
                        Toggle("", isOn: Binding(
                            get: { model.isEnabled },
                            set: { newValue in
                                var m = model
                                m.isEnabled = newValue
                                configStorage.updateModel(m)
                            }
                        ))
                        .labelsHidden()

                        // Delete Button
                        Button(action: { configStorage.deleteModel(id: model.id) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .sheet(isPresented: $showingAddModelSheet) {
            AddModelSheet(configStorage: configStorage, isPresented: $showingAddModelSheet)
        }
    }

    private func testModel(_ model: ModelConfig) {
        guard let provider = configStorage.getProvider(for: model) else {
            testStatusMap[model.id] = "✕ 无供应商"
            return
        }
        if provider.apiKey.isEmpty {
            testStatusMap[model.id] = "✕ 未填 Key"
            return
        }

        testStatusMap[model.id] = "检测中..."
        Task {
            do {
                let service = AIServiceFactory.service(for: provider)
                let ok = try await service.testConnection(model: model, provider: provider)
                await MainActor.run {
                    testStatusMap[model.id] = ok ? "✓ 连通正常" : "✕ 返回空"
                }
            } catch {
                await MainActor.run {
                    testStatusMap[model.id] = "✕ 失败: \(error.localizedDescription.prefix(15))"
                }
            }
        }
    }
}

// MARK: - Add Model Sheet
struct AddModelSheet: View {
    @ObservedObject var configStorage: ConfigStorage
    @Binding var isPresented: Bool

    @State private var selectedProviderId: UUID = UUID()
    @State private var modelIdentifier: String = ""
    @State private var displayName: String = ""
    @State private var temperature: Double = 0.2

    var selectedProvider: AIProviderConfig? {
        configStorage.providers.first(where: { $0.id == selectedProviderId })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加新模型")
                .font(.headline)

            Form {
                Picker("选择供应商", selection: $selectedProviderId) {
                    ForEach(configStorage.providers) { p in
                        Text(p.name).tag(p.id)
                    }
                }
                .onChange(of: selectedProviderId) { newId in
                    if let p = configStorage.providers.first(where: { $0.id == newId }),
                       let firstModel = p.type.defaultModels.first {
                        modelIdentifier = firstModel
                        displayName = "\(p.name) - \(firstModel)"
                    }
                }

                if let p = selectedProvider, !p.type.defaultModels.isEmpty {
                    Picker("预置常用模型", selection: $modelIdentifier) {
                        ForEach(p.type.defaultModels, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                    .onChange(of: modelIdentifier) { newModel in
                        if let p = selectedProvider {
                            displayName = "\(p.name) - \(newModel)"
                        }
                    }
                }

                TextField("模型识别名 (model)", text: $modelIdentifier)
                TextField("显示别名 (如：主力-V3)", text: $displayName)

                HStack {
                    Text("温度 (Temperature): \(String(format: "%.1f", temperature))")
                    Slider(value: $temperature, in: 0.0...1.0, step: 0.1)
                }
            }

            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                Button("添加") {
                    let newModel = ModelConfig(
                        providerId: selectedProviderId,
                        modelIdentifier: modelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
                        displayName: displayName.isEmpty ? modelIdentifier : displayName,
                        isEnabled: true,
                        temperature: temperature
                    )
                    configStorage.addModel(newModel)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(modelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear {
            if let first = configStorage.providers.first {
                selectedProviderId = first.id
                modelIdentifier = first.type.defaultModels.first ?? ""
                displayName = "\(first.name) - \(modelIdentifier)"
            }
        }
    }
}

// MARK: - Tab 2: 供应商设置
struct ProviderSettingsView: View {
    @ObservedObject var configStorage: ConfigStorage
    @State private var showingKeys: [UUID: Bool] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AI 供应商连接与凭证")
                .font(.title3)
                .fontWeight(.bold)
            Text("在此配置各平台的 API 地址与 API Key，密钥将安全存储在 macOS 系统钥匙串 (Keychain) 中。")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(configStorage.providers) { provider in
                        GroupBox(label: HStack {
                            Image(systemName: provider.type.iconName)
                                .foregroundColor(.accentColor)
                            Text(provider.name).fontWeight(.semibold)
                        }) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Base URL:")
                                        .font(.caption)
                                        .frame(width: 70, alignment: .trailing)
                                    TextField("https://...", text: Binding(
                                        get: { provider.apiBaseURL },
                                        set: { val in
                                            var p = provider
                                            p.apiBaseURL = val
                                            configStorage.updateProvider(p)
                                        }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                }

                                HStack {
                                    Text("API Key:")
                                        .font(.caption)
                                        .frame(width: 70, alignment: .trailing)
                                    let isShowing = showingKeys[provider.id] ?? false
                                    if isShowing {
                                        TextField("sk-...", text: Binding(
                                            get: { provider.apiKey },
                                            set: { val in
                                                var p = provider
                                                p.apiKey = val
                                                configStorage.updateProvider(p)
                                            }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                    } else {
                                        SecureField("sk-...", text: Binding(
                                            get: { provider.apiKey },
                                            set: { val in
                                                var p = provider
                                                p.apiKey = val
                                                configStorage.updateProvider(p)
                                            }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                    }

                                    Button(action: {
                                        showingKeys[provider.id] = !(showingKeys[provider.id] ?? false)
                                    }) {
                                        Image(systemName: isShowing ? "eye.slash" : "eye")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding(8)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tab 3: 提示词模板
struct PromptSettingsView: View {
    @ObservedObject var configStorage: ConfigStorage
    @State private var selectedPrompt: PromptTemplate?

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("整理提示词模板")
                    .font(.headline)

                List(configStorage.prompts, selection: $selectedPrompt) { prompt in
                    HStack {
                        Image(systemName: prompt.icon)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(prompt.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if prompt.id == configStorage.preferences.activePromptId {
                                    Text("默认")
                                        .font(.system(size: 9))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.accentColor.opacity(0.15))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(3)
                                }
                            }
                            Text(prompt.shortDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .tag(prompt)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
            .frame(width: 280)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                if let p = selectedPrompt ?? configStorage.prompts.first {
                    HStack {
                        Text(p.name).font(.title3).fontWeight(.bold)
                        Spacer()
                        if p.id != configStorage.preferences.activePromptId {
                            Button("设为当前默认") {
                                configStorage.setActivePrompt(id: p.id)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Text(p.shortDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("System Prompt (系统指令)")
                        .font(.caption)
                        .fontWeight(.semibold)

                    ScrollView {
                        Text(p.systemPrompt)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                } else {
                    Text("请从左侧选择一个提示词模板")
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            selectedPrompt = configStorage.getActivePrompt()
        }
    }
}

// MARK: - Tab 4: 通用设置
struct GeneralSettingsView: View {
    @ObservedObject var configStorage: ConfigStorage
    @State private var isAccessibilityOk: Bool = PermissionsManager.shared.isAccessibilityTrusted

    var body: some View {
        Form {
            Section(header: Text("辅助功能权限 (Accessibility)").font(.headline)) {
                HStack {
                    if isAccessibilityOk {
                        Label("辅助功能权限已授予", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("辅助功能权限未就绪", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        Button("去授权") {
                            PermissionsManager.shared.openAccessibilityPreferences()
                        }
                    }
                    Spacer()
                    Button("刷新状态") {
                        isAccessibilityOk = PermissionsManager.shared.isAccessibilityTrusted
                    }
                }
            }

            Section(header: Text("交互行为 (方案 B)").font(.headline)) {
                Toggle("触发后直接在原位替换文本", isOn: $configStorage.preferences.autoReplaceInPlace)
                Toggle("完成时播放轻量提示音", isOn: $configStorage.preferences.playFeedbackSound)
            }

            Section(header: Text("全局呼出快捷键 (点击修改)").font(.headline)) {
                ShortcutRecorderView(configStorage: configStorage)
                Text("在任意软件中选中文本后按下该快捷键，AI 将立即整理并原位替换。修改后实时生效，无需重启。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
    }
}
