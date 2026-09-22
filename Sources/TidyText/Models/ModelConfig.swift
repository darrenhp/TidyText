import Foundation

public struct ModelConfig: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var providerId: UUID
    public var modelIdentifier: String // e.g. "deepseek-chat", "claude-3-7-sonnet-20250219"
    public var displayName: String // e.g. "DeepSeek V3 (主力)", "Claude 3.7"
    public var isEnabled: Bool
    public var priority: Int // 0, 1, 2, ... Lower is higher priority
    public var temperature: Double
    public var maxTokens: Int

    public init(
        id: UUID = UUID(),
        providerId: UUID,
        modelIdentifier: String,
        displayName: String,
        isEnabled: Bool = true,
        priority: Int = 0,
        temperature: Double = 0.2,
        maxTokens: Int = 2048
    ) {
        self.id = id
        self.providerId = providerId
        self.modelIdentifier = modelIdentifier
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.priority = priority
        self.temperature = temperature
        self.maxTokens = maxTokens
    }

    public static func defaultModels(for providers: [AIProviderConfig]) -> [ModelConfig] {
        var models: [ModelConfig] = []
        var priorityCounter = 0

        // Find deepseek provider
        if let ds = providers.first(where: { $0.type == .deepseek }) {
            models.append(ModelConfig(
                id: UUID(uuidString: "aaaaaaaa-1111-0000-0000-000000000001")!,
                providerId: ds.id,
                modelIdentifier: "deepseek-flash",
                displayName: "DeepSeek V4.1 Flash (推荐主用)",
                isEnabled: true,
                priority: priorityCounter,
                temperature: 0.2
            ))
            priorityCounter += 1
        }

        // Find doubao provider
        if let db = providers.first(where: { $0.type == .doubao }) {
            models.append(ModelConfig(
                id: UUID(uuidString: "bbbbbbbb-2222-0000-0000-000000000002")!,
                providerId: db.id,
                modelIdentifier: "doubao-pro-4k",
                displayName: "火山引擎 豆包 Pro",
                isEnabled: true,
                priority: priorityCounter,
                temperature: 0.2
            ))
            priorityCounter += 1
        }

        // Find claude provider
        if let cl = providers.first(where: { $0.type == .claude }) {
            models.append(ModelConfig(
                id: UUID(uuidString: "cccccccc-3333-0000-0000-000000000003")!,
                providerId: cl.id,
                modelIdentifier: "claude-3-5-haiku-20241022",
                displayName: "Claude 3.5 Haiku (极速备用)",
                isEnabled: false,
                priority: priorityCounter,
                temperature: 0.2
            ))
            priorityCounter += 1
        }

        // Find openai provider
        if let oa = providers.first(where: { $0.type == .openai }) {
            models.append(ModelConfig(
                id: UUID(uuidString: "dddddddd-4444-0000-0000-000000000004")!,
                providerId: oa.id,
                modelIdentifier: "gpt-4o-mini",
                displayName: "OpenAI GPT-4o-mini",
                isEnabled: false,
                priority: priorityCounter,
                temperature: 0.2
            ))
            priorityCounter += 1
        }

        return models
    }
}
