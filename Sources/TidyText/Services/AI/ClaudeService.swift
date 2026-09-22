import Foundation

public final class ClaudeService: AIServiceProtocol {
    public static let shared = ClaudeService()

    private init() {}

    private func buildEndpointURL(baseURL: String) -> URL? {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/messages") {
            return URL(string: trimmed)
        }
        if trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        if trimmed.hasSuffix("/v1") {
            return URL(string: "\(trimmed)/messages")
        }
        return URL(string: "\(trimmed)/v1/messages")
    }

    public func tidy(
        prompt: PromptTemplate,
        text: String,
        model: ModelConfig,
        provider: AIProviderConfig
    ) async throws -> String {
        guard let url = buildEndpointURL(baseURL: provider.apiBaseURL) else {
            throw TidyError.invalidURL(provider.apiBaseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(provider.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        for (k, v) in provider.customHeaders {
            request.setValue(v, forHTTPHeaderField: k)
        }

        let payload: [String: Any] = [
            "model": model.modelIdentifier,
            "system": prompt.systemPrompt,
            "max_tokens": model.maxTokens,
            "temperature": model.temperature,
            "messages": [
                ["role": "user", "content": prompt.renderUserPrompt(text: text)]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TidyError.networkError("未能获取有效的 HTTP 响应")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw TidyError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        struct ClaudeResponse: Decodable {
            struct ContentBlock: Decodable {
                let type: String?
                let text: String?
            }
            let content: [ContentBlock]?
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        let textResult = decoded.content?.compactMap { $0.text }.joined() ?? ""
        let trimmedResult = textResult.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedResult.isEmpty else {
            throw TidyError.emptyResponse
        }

        return trimmedResult
    }

    public func testConnection(
        model: ModelConfig,
        provider: AIProviderConfig
    ) async throws -> Bool {
        let dummyPrompt = PromptTemplate(
            name: "Ping",
            systemPrompt: "Reply 'ok'.",
            userPromptTemplate: "ping"
        )
        let res = try await tidy(prompt: dummyPrompt, text: "ping", model: model, provider: provider)
        return !res.isEmpty
    }
}
