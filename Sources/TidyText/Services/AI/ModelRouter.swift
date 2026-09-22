import Foundation

public struct TidyExecutionResult {
    public let resultText: String
    public let model: ModelConfig
    public let provider: AIProviderConfig

    public init(resultText: String, model: ModelConfig, provider: AIProviderConfig) {
        self.resultText = resultText
        self.model = model
        self.provider = provider
    }
}

public final class ModelRouter {
    public static let shared = ModelRouter()

    private init() {}

    public func executeTidy(
        prompt: PromptTemplate,
        text: String,
        configStorage: ConfigStorage = .shared,
        onStatusUpdate: ((String) -> Void)? = nil
    ) async throws -> TidyExecutionResult {
        let enabledModels = configStorage.getEnabledModelsSortedByPriority()

        guard !enabledModels.isEmpty else {
            throw TidyError.noModelEnabled
        }

        var failureLogs: [String] = []

        for (index, model) in enabledModels.enumerated() {
            guard let provider = configStorage.getProvider(for: model) else {
                failureLogs.append("[\(model.displayName)]: 找不到供应商配置")
                continue
            }

            // Check API Key
            if provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failureLogs.append("[\(model.displayName)]: 供应商 \(provider.name) 未配置 API Key")
                continue
            }

            let statusMessage = index == 0
                ? "正在使用 \(model.displayName) 整理..."
                : "主用模型失败，切换备用模型 \(model.displayName) 重试..."

            onStatusUpdate?(statusMessage)

            do {
                let service = AIServiceFactory.service(for: provider)
                let result = try await service.tidy(prompt: prompt, text: text, model: model, provider: provider)
                return TidyExecutionResult(resultText: result, model: model, provider: provider)
            } catch {
                let errorDesc = error.localizedDescription
                failureLogs.append("[\(model.displayName)]: \(errorDesc)")
                print("[ModelRouter] Fallback triggered. Model \(model.displayName) failed: \(errorDesc)")
            }
        }

        throw TidyError.allModelsFailed(failureLogs)
    }
}
