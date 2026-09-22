import Foundation

public enum ProviderType: String, Codable, CaseIterable, Identifiable {
    case deepseek = "deepseek"
    case claude = "claude"
    case openai = "openai"
    case doubao = "doubao"
    case custom = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .claude: return "Anthropic Claude"
        case .openai: return "OpenAI"
        case .doubao: return "火山引擎 豆包 (Doubao)"
        case .custom: return "自定义 (OpenAI 兼容 / Ollama)"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .deepseek: return "https://api.deepseek.com/v1"
        case .claude: return "https://api.anthropic.com/v1/messages"
        case .openai: return "https://api.openai.com/v1"
        case .doubao: return "https://ark.cn-beijing.volces.com/api/v3"
        case .custom: return "http://localhost:11434/v1"
        }
    }

    public var defaultModels: [String] {
        switch self {
        case .deepseek:
            return ["deepseek-chat", "deepseek-reasoner"]
        case .claude:
            return ["claude-3-7-sonnet-20250219", "claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022"]
        case .openai:
            return ["gpt-4o", "gpt-4o-mini", "o3-mini", "gpt-4-turbo"]
        case .doubao:
            return ["doubao-pro-4k", "doubao-pro-32k", "doubao-lite-4k"]
        case .custom:
            return ["qwen2.5:7b", "llama3.2:latest", "mistral:latest"]
        }
    }

    public var iconName: String {
        switch self {
        case .deepseek: return "brain.head.profile"
        case .claude: return "sparkles"
        case .openai: return "globe"
        case .doubao: return "leaf.fill"
        case .custom: return "server.rack"
        }
    }
}

public struct AIProviderConfig: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var type: ProviderType
    public var name: String
    public var apiBaseURL: String
    public var apiKey: String // Stored securely; in serialized JSON this can be masked or empty if Keychain is used
    public var customHeaders: [String: String]

    public init(
        id: UUID = UUID(),
        type: ProviderType,
        name: String? = nil,
        apiBaseURL: String? = nil,
        apiKey: String = "",
        customHeaders: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.name = name ?? type.displayName
        self.apiBaseURL = apiBaseURL ?? type.defaultBaseURL
        self.apiKey = apiKey
        self.customHeaders = customHeaders
    }

    public static func defaultProviders() -> [AIProviderConfig] {
        return [
            AIProviderConfig(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                type: .deepseek,
                name: "DeepSeek",
                apiBaseURL: ProviderType.deepseek.defaultBaseURL
            ),
            AIProviderConfig(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                type: .doubao,
                name: "火山引擎 豆包",
                apiBaseURL: ProviderType.doubao.defaultBaseURL
            ),
            AIProviderConfig(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                type: .claude,
                name: "Claude",
                apiBaseURL: ProviderType.claude.defaultBaseURL
            ),
            AIProviderConfig(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                type: .openai,
                name: "OpenAI",
                apiBaseURL: ProviderType.openai.defaultBaseURL
            ),
            AIProviderConfig(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                type: .custom,
                name: "自定义 / Ollama",
                apiBaseURL: ProviderType.custom.defaultBaseURL
            )
        ]
    }
}
