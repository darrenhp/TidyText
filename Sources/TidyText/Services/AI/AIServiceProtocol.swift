import Foundation

public enum TidyError: LocalizedError {
    case noModelEnabled
    case providerNotFound(UUID)
    case missingAPIKey(String)
    case invalidURL(String)
    case networkError(String)
    case apiError(statusCode: Int, message: String)
    case emptyResponse
    case allModelsFailed([String])

    public var errorDescription: String? {
        switch self {
        case .noModelEnabled:
            return "未启用任何模型，请在设置中配置并启用至少一个模型。"
        case .providerNotFound(let id):
            return "找不到模型对应的供应商配置 (ID: \(id.uuidString))。"
        case .missingAPIKey(let providerName):
            return "供应商 [\(providerName)] 未配置 API Key，请在设置中填写。"
        case .invalidURL(let url):
            return "无效的 API 地址: \(url)"
        case .networkError(let msg):
            return "网络请求失败: \(msg)"
        case .apiError(let statusCode, let message):
            return "API 报错 [HTTP \(statusCode)]: \(message)"
        case .emptyResponse:
            return "大模型返回了空结果。"
        case .allModelsFailed(let errors):
            return "所有已启用的模型均调用失败:\n" + errors.joined(separator: "\n")
        }
    }
}

public protocol AIServiceProtocol {
    func tidy(
        prompt: PromptTemplate,
        text: String,
        model: ModelConfig,
        provider: AIProviderConfig
    ) async throws -> String

    func testConnection(
        model: ModelConfig,
        provider: AIProviderConfig
    ) async throws -> Bool
}
