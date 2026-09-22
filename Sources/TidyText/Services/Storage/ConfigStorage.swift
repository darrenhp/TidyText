import Foundation
import Combine

public struct UserPreferences: Codable {
    public var activePromptId: UUID
    public var autoReplaceInPlace: Bool
    public var playFeedbackSound: Bool
    public var hotKeyKeyCode: UInt32 // e.g. 49 for Space
    public var hotKeyModifiers: UInt32 // e.g. optionKey
    public var maxHistoryCount: Int

    public init(
        activePromptId: UUID = UUID(uuidString: "99999999-0001-0000-0000-000000000001")!,
        autoReplaceInPlace: Bool = true,
        playFeedbackSound: Bool = true,
        hotKeyKeyCode: UInt32 = 49, // Space
        hotKeyModifiers: UInt32 = 2048, // optionKey
        maxHistoryCount: Int = 30
    ) {
        self.activePromptId = activePromptId
        self.autoReplaceInPlace = autoReplaceInPlace
        self.playFeedbackSound = playFeedbackSound
        self.hotKeyKeyCode = hotKeyKeyCode
        self.hotKeyModifiers = hotKeyModifiers
        self.maxHistoryCount = maxHistoryCount
    }
}

public final class ConfigStorage: ObservableObject {
    public static let shared = ConfigStorage()

    @Published public var providers: [AIProviderConfig] = []
    @Published public var models: [ModelConfig] = []
    @Published public var prompts: [PromptTemplate] = []
    @Published public var preferences: UserPreferences = UserPreferences()

    private let fileManager = FileManager.default
    private let configDirectoryURL: URL
    private let configFileURL: URL

    public init(customBaseDirectory: URL? = nil) {
        if let baseDir = customBaseDirectory {
            self.configDirectoryURL = baseDir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.configDirectoryURL = appSupport.appendingPathComponent("TidyText", isDirectory: true)
        }
        self.configFileURL = self.configDirectoryURL.appendingPathComponent("config.json")

        load()
    }

    // MARK: - Model Priority Helpers

    public func getEnabledModelsSortedByPriority() -> [ModelConfig] {
        return models
            .filter { $0.isEnabled }
            .sorted { $0.priority < $1.priority }
    }

    public func getProvider(for model: ModelConfig) -> AIProviderConfig? {
        return providers.first(where: { $0.id == model.providerId })
    }

    public func moveModel(fromOffsets source: IndexSet, toOffset destination: Int) {
        var updated = models
        let movingItems = source.map { updated[$0] }
        for index in source.reversed() {
            updated.remove(at: index)
        }
        let insertIndex = destination > updated.count ? updated.count : (destination - source.filter { $0 < destination }.count)
        updated.insert(contentsOf: movingItems, at: max(0, insertIndex))
        self.models = updated
        reindexModelPriorities()
        save()
    }

    public func moveModelUp(modelId: UUID) {
        guard let index = models.firstIndex(where: { $0.id == modelId }), index > 0 else { return }
        models.swapAt(index, index - 1)
        reindexModelPriorities()
        save()
    }

    public func moveModelDown(modelId: UUID) {
        guard let index = models.firstIndex(where: { $0.id == modelId }), index < models.count - 1 else { return }
        models.swapAt(index, index + 1)
        reindexModelPriorities()
        save()
    }

    private func reindexModelPriorities() {
        for (index, _) in models.enumerated() {
            models[index].priority = index
        }
    }

    public func updateModel(_ model: ModelConfig) {
        if let index = models.firstIndex(where: { $0.id == model.id }) {
            models[index] = model
            save()
        }
    }

    public func addModel(_ model: ModelConfig) {
        var newModel = model
        newModel.priority = models.count
        models.append(newModel)
        save()
    }

    public func deleteModel(id: UUID) {
        models.removeAll(where: { $0.id == id })
        reindexModelPriorities()
        save()
    }

    // MARK: - Provider Helpers

    public func updateProvider(_ provider: AIProviderConfig) {
        if let index = providers.firstIndex(where: { $0.id == provider.id }) {
            providers[index] = provider
            // Save API key securely to Keychain
            KeychainManager.shared.save(key: "provider_key_\(provider.id.uuidString)", value: provider.apiKey)
            save()
        }
    }

    // MARK: - Prompt Helpers

    public func getActivePrompt() -> PromptTemplate {
        if let found = prompts.first(where: { $0.id == preferences.activePromptId }) {
            return found
        }
        return prompts.first(where: { $0.isDefault }) ?? prompts.first ?? PromptTemplate.defaultTemplates()[0]
    }

    public func setActivePrompt(id: UUID) {
        preferences.activePromptId = id
        save()
    }

    // MARK: - Persistence

    private struct PersistedData: Codable {
        var providers: [AIProviderConfig]
        var models: [ModelConfig]
        var prompts: [PromptTemplate]
        var preferences: UserPreferences
    }

    public func save() {
        do {
            if !fileManager.fileExists(atPath: configDirectoryURL.path) {
                try fileManager.createDirectory(at: configDirectoryURL, withIntermediateDirectories: true)
            }

            // Scrub API keys before writing config.json to disk; keys belong in Keychain
            let sanitizedProviders = providers.map { provider -> AIProviderConfig in
                var p = provider
                p.apiKey = "" // Keep empty in json file
                return p
            }

            let data = PersistedData(
                providers: sanitizedProviders,
                models: models,
                prompts: prompts,
                preferences: preferences
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let encoded = try encoder.encode(data)
            try encoded.write(to: configFileURL, options: .atomic)
        } catch {
            print("[ConfigStorage] Save failed: \(error)")
        }
    }

    public func load() {
        if fileManager.fileExists(atPath: configFileURL.path) {
            do {
                let data = try Data(contentsOf: configFileURL)
                let decoded = try JSONDecoder().decode(PersistedData.self, from: data)

                // Restore API keys from Keychain
                self.providers = decoded.providers.map { provider in
                    var p = provider
                    if let key = KeychainManager.shared.get(key: "provider_key_\(provider.id.uuidString)"), !key.isEmpty {
                        p.apiKey = key
                    }
                    return p
                }
                self.models = decoded.models
                self.prompts = decoded.prompts.isEmpty ? PromptTemplate.defaultTemplates() : decoded.prompts
                self.preferences = decoded.preferences
                return
            } catch {
                print("[ConfigStorage] Load error, falling back to defaults: \(error)")
            }
        }

        // Initialize with sensible defaults
        let defProviders = AIProviderConfig.defaultProviders()
        self.providers = defProviders.map { provider in
            var p = provider
            if let key = KeychainManager.shared.get(key: "provider_key_\(provider.id.uuidString)") {
                p.apiKey = key
            }
            return p
        }
        self.models = ModelConfig.defaultModels(for: defProviders)
        self.prompts = PromptTemplate.defaultTemplates()
        self.preferences = UserPreferences()
        save()
    }
}
