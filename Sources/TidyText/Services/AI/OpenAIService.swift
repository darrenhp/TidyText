import Foundation

public final class OpenAIService: AIServiceProtocol {
    public static let shared = OpenAIService()

    private init() {}

    private func buildEndpointURL(baseURL: String) -> URL? {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/chat/completions") {
            return URL(string: trimmed)
        }
        if trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return URL(string: "\(trimmed)/chat/completions")
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

        if !provider.apiKey.isEmpty {
            request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        }

        for (k, v) in provider.customHeaders {
            request.setValue(v, forHTTPHeaderField: k)
        }

        let payload: [String: Any] = [
            "model": model.modelIdentifier,
            "temperature": model.temperature,
            "max_tokens": model.maxTokens,
            "messages": [
                ["role": "system", "content": prompt.systemPrompt],
                ["role": "user", "content": prompt.renderUserPrompt(text: text)]
            ],
            "stream": false
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

        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String?
                }
                let message: Message?
            }
            let choices: [Choice]?
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = decoded.choices?.first?.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw TidyError.emptyResponse
        }

        return content
    }

    public func testConnection(
        model: ModelConfig,
        provider: AIProviderConfig
    ) async throws -> Bool {
        let dummyPrompt = PromptTemplate(
            name: "Ping",
            systemPrompt: "You are a test assistant. Reply 'ok'.",
            userPromptTemplate: "ping"
        )
        let res = try await tidy(prompt: dummyPrompt, text: "ping", model: model, provider: provider)
        return !res.isEmpty
    }
}
