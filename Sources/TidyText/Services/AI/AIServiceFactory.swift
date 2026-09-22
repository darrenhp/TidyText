import Foundation

public final class AIServiceFactory {
    public static func service(for provider: AIProviderConfig) -> AIServiceProtocol {
        switch provider.type {
        case .claude:
            return ClaudeService.shared
        case .deepseek, .openai, .doubao, .custom:
            return OpenAIService.shared
        }
    }
}
